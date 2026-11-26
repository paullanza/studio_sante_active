require "rails_helper"

RSpec.describe Session, type: :model do
  let(:definition) { create(:service_definition, paid_sessions: 2, free_sessions: 1) }
  let(:service)    { create(:fliip_service, service_definition: definition) }
  let(:staff)      { create(:user) }

  def build_session(**attrs)
    build(:session, fliip_service: service, user: staff, **attrs)
  end

  describe "session type" do
    it "is paid when the client was present" do
      session = create(:session, fliip_service: service, present: true)
      expect(session).to be_paid
    end

    it "is free when the client was absent and free sessions remain" do
      session = create(:session, fliip_service: service, present: false)
      expect(session).to be_free
    end

    it "falls back to paid when the client was absent but no free sessions remain" do
      create(:session, fliip_service: service, present: false, occurred_at: 1.day.ago)
      session = create(:session, fliip_service: service, present: false)

      expect(session).to be_paid
    end


    it "defaults duration to 1 hour" do
      session = create(:session, fliip_service: service, duration: nil)
      expect(session.duration).to eq(1.0)
    end
  end

  describe "quota limits" do
    it "rejects a paid session when no paid sessions remain" do
      create(:session, fliip_service: service, occurred_at: 1.day.ago)
      create(:session, fliip_service: service, occurred_at: 2.days.ago)
      session = build_session(present: true)

      expect(session).not_to be_valid
      expect(session.errors[:base]).to include("Aucune séance payante disponible pour ce service.")
    end

    it "rejects a session longer than what remains" do
      create(:service_usage_adjustment, fliip_service: service, paid_used_delta: 1.5)
      session = build_session(present: true, duration: 1.0)

      expect(session).not_to be_valid
      expect(session.errors[:base]).to include("Aucune séance payante disponible pour ce service.")
    end

    it "allows a half-hour session when half an hour remains" do
      create(:service_usage_adjustment, fliip_service: service, paid_used_delta: 1.5)
      session = build_session(present: true, duration: 0.5)

      expect(session).to be_valid
    end
  end

  describe "service checks" do
    it "rejects a service whose allocation is « à définir »" do
      definition.update_columns(paid_sessions: nil, free_sessions: nil)
      session = build_session(present: false)

      expect(session).not_to be_valid
      expect(session.errors[:base]).to contain_exactly("L'allocation de ce service est à définir.")
    end

    it "rejects a service with no allocation at all" do
      session = build(:session, fliip_service: create(:fliip_service, :without_definition), user: staff)

      expect(session).not_to be_valid
      expect(session.errors[:base]).to include("L'allocation de ce service est à définir.")
    end

    it "rejects cancelled services" do
      service.update!(purchase_status: "C")
      session = build_session

      expect(session).not_to be_valid
      expect(session.errors[:base]).to include("Ce service est annulé. Impossible de créer une séance.")
    end

    it "rejects services missing from Fliip" do
      service.update!(missing_from_fliip_at: 1.day.ago)
      session = build_session

      expect(session).not_to be_valid
      expect(session.errors[:base]).to include("Ce service a été retiré de Fliip. Impossible de créer une séance.")
    end

    it "rejects services whose client is missing from Fliip" do
      service.fliip_user.update!(missing_from_fliip_at: 1.day.ago)

      expect(build_session).not_to be_valid
    end

    it "keeps existing sessions valid once their service is flagged" do
      session = build_session
      session.save!
      service.update!(missing_from_fliip_at: 1.day.ago)

      expect(session.reload).to be_valid
    end

    it "rejects a service starting more than 30 days from today" do
      service.update!(start_date: 31.days.from_now.to_date, expire_date: 1.year.from_now.to_date)
      session = build_session(occurred_at: service.start_date)

      expect(session).not_to be_valid
      expect(session.errors[:base]).to include(
        "La date de début de ce service est dans plus de 30 jours. Impossible de créer une séance."
      )
    end

    it "rejects a service that ended more than 30 days ago" do
      service.update!(start_date: 1.year.ago.to_date, expire_date: 31.days.ago.to_date)
      session = build_session(occurred_at: service.expire_date)

      expect(session).not_to be_valid
      expect(session.errors[:base]).to include(
        "Ce service est terminé depuis plus de 30 jours. Impossible de créer une séance."
      )
    end

    it "accepts a service that ended less than 30 days ago" do
      service.update!(start_date: 1.year.ago.to_date, expire_date: 10.days.ago.to_date)
      expect(build_session).to be_valid
    end

    it "rejects a session dated more than 30 days after the service expired" do
      session = build_session(occurred_at: service.expire_date + 31.days)
      expect(session).not_to be_valid
      expect(session.errors[:base]).to include("Le service est terminé depuis plus de 30 jours.")
    end

    it "rejects a service that belongs to another client" do
      session = build_session(fliip_user: create(:fliip_user))

      expect(session).not_to be_valid
      expect(session.errors[:fliip_service_id]).to include("ne correspond pas au client sélectionné.")
    end

    it "rejects a duplicate booking for the same client, service and time" do
      existing = create(:session, fliip_service: service)
      duplicate = build_session(occurred_at: existing.occurred_at)

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:fliip_user_id]).to include(
        "a déjà une séance prévue à cette heure-là avec ce service."
      )
    end
  end

  describe ".confirm" do
    let(:admin) { create(:user, :admin) }

    it "confirms only unconfirmed sessions, records who did it, and returns the count" do
      first  = create(:session, fliip_service: service, occurred_at: 1.day.ago)
      second = create(:session, fliip_service: service, occurred_at: 2.days.ago)
      second.update_columns(confirmed: true)

      expect(described_class.confirm([first.id, second.id], by: admin)).to eq(1)
      expect(first.reload).to have_attributes(confirmed: true, confirmed_by: admin)
      expect(first.confirmed_at).to be_present
      expect(second.reload.confirmed_by).to be_nil
    end

    it "returns 0 for no ids" do
      expect(described_class.confirm([], by: admin)).to eq(0)
    end
  end

  describe ".in_period" do
    it "keeps the séances from Sunday 00:00 to Saturday 23:59 of the period" do
      period = PayPeriod.containing(Date.new(2026, 11, 8))
      roomy = create(:fliip_service, service_definition: create(:service_definition, paid_sessions: 10, free_sessions: 0))
      at = ->(time) { create(:session, fliip_service: roomy).tap { |s| s.update_columns(occurred_at: time) } }
      inside_first = at.call(Time.zone.local(2026, 11, 8, 0, 0))
      inside_last = at.call(Time.zone.local(2026, 11, 21, 23, 30))
      at.call(Time.zone.local(2026, 11, 7, 23, 30))
      at.call(Time.zone.local(2026, 11, 22, 0, 0))

      expect(described_class.in_period(period)).to contain_exactly(inside_first, inside_last)
    end
  end

  describe "defaults and validations" do
    it "defaults created_by to the responsible user" do
      session = build_session(created_by: nil)
      session.save!

      expect(session.created_by).to eq(staff)
    end

    it "rejects a non-positive duration" do
      session = build_session(duration: -1)

      expect(session).not_to be_valid
      expect(session.errors[:duration]).to be_present
    end

    it "accepts only 1 h or 30 min" do
      expect(build_session(duration: 1.0)).to be_valid
      expect(build_session(duration: 0.5)).to be_valid

      session = build_session(duration: 2.0)
      expect(session).not_to be_valid
      expect(session.errors[:duration]).to include("doit être 1 h ou 30 min")
    end
  end

  describe "status and ordering scopes" do
    let(:roomy) { create(:fliip_service, service_definition: create(:service_definition, paid_sessions: 20, free_sessions: 5)) }
    let!(:older) { create(:session, fliip_service: roomy, occurred_at: 2.days.ago.change(min: 0)) }
    let!(:newer) { create(:session, fliip_service: roomy, occurred_at: 1.day.ago.change(min: 0)) }

    it "treats nil and false as unconfirmed" do
      older.update_columns(confirmed: nil)
      newer.update_columns(confirmed: true)

      expect(described_class.unconfirmed).to contain_exactly(older)
      expect(described_class.confirmed).to contain_exactly(newer)
    end

    it "orders by occurred_at" do
      expect(described_class.order_by_occurred_at_desc).to eq([newer, older])
      expect(described_class.order_by_occurred_at_asc).to eq([older, newer])
    end
  end

  describe "filters" do
    # Freeze time before the let! records: the service factory dates itself from "now".
    before { travel_to Time.zone.local(2026, 10, 25, 12) }

    let(:roomy)  { create(:fliip_service, service_definition: create(:service_definition, paid_sessions: 20, free_sessions: 5)) }
    let(:other)  { create(:user) }
    let!(:present_paid) do
      create(:session, fliip_service: roomy, user: staff, present: true, occurred_at: Time.zone.local(2026, 10, 5, 10))
    end
    let!(:absent_free) do
      create(:session, fliip_service: roomy, user: other, present: false, occurred_at: Time.zone.local(2026, 10, 20, 10))
    end

    it ".by_employee filters by user and ignores a blank id" do
      expect(described_class.by_employee(staff.id)).to contain_exactly(present_paid)
      expect(described_class.by_employee("")).to contain_exactly(present_paid, absent_free)
    end

    it ".date_between filters on the occurred_at date, open on either side" do
      expect(described_class.date_between("2026-10-01", "2026-10-10")).to contain_exactly(present_paid)
      expect(described_class.date_between("2026-10-15", nil)).to contain_exactly(absent_free)
      expect(described_class.date_between(nil, nil)).to contain_exactly(present_paid, absent_free)
    end

    it ".created_between filters on created_at" do
      present_paid.update_columns(created_at: Time.zone.local(2026, 9, 1))

      expect(described_class.created_between("2026-10-01", nil)).to contain_exactly(absent_free)
      expect(described_class.created_between(nil, "2026-09-02")).to contain_exactly(present_paid)
    end

    it ".present_value accepts yes, no, both or nothing" do
      expect(described_class.present_value("yes")).to contain_exactly(present_paid)
      expect(described_class.present_value(["no"])).to contain_exactly(absent_free)
      expect(described_class.present_value(%w[yes no])).to contain_exactly(present_paid, absent_free)
      expect(described_class.present_value(nil)).to contain_exactly(present_paid, absent_free)
    end

    it ".of_type accepts paid, free, both or nothing" do
      expect(described_class.of_type("paid")).to contain_exactly(present_paid)
      expect(described_class.of_type(["free"])).to contain_exactly(absent_free)
      expect(described_class.of_type(%w[paid free])).to contain_exactly(present_paid, absent_free)
      expect(described_class.of_type([])).to contain_exactly(present_paid, absent_free)
    end

    it ".apply_filters chains the filters, including a client name search" do
      roomy.fliip_user.update!(user_firstname: "Gabrielle", user_lastname: "Tremblay")

      result = described_class.apply_filters(q: "Gabri", employee_id: other.id, present: ["no"], session_type: ["free"])
      expect(result).to contain_exactly(absent_free)

      expect(described_class.apply_filters(q: "Personne")).to be_empty
    end
  end

  describe "display helpers" do
    it "#duration_display names full and half hours" do
      expect(build_session(duration: 1.0).duration_display).to eq("1 heure")
      expect(build_session(duration: 0.5).duration_display).to eq("Demi-heure")
      expect(build_session(duration: 1.5).duration_display).to eq("1.5 h")
    end

    it "#presence_label and #presence_badge_variant reflect presence and type" do
      present = build_session(present: true, session_type: :paid)
      late    = build_session(present: false, session_type: :paid)
      absence = build_session(present: false, session_type: :free)

      expect([present, late, absence].map(&:presence_label)).to eq(["Présent", "Absent (-24h)", "Absent"])
      expect([present, late, absence].map(&:presence_badge_variant)).to eq(%w[bg-success bg-danger bg-warning])
    end

    it "#presence_with_duration_label combines both" do
      expect(build_session(present: true, duration: 0.5).presence_with_duration_label).to eq("Demi-heure Présent")
    end

    it "#date_time_label and #created_at_label format in dd/mm/yyyy" do
      session = build_session(occurred_at: Time.zone.local(2026, 3, 4, 9, 30), created_at: Time.zone.local(2026, 3, 5, 8, 0))

      expect(session.date_time_label).to eq("04/03/2026 09:30")
      expect(session.created_at_label).to eq("créé : 05/03/2026 08:00")
      expect(build_session(occurred_at: nil).date_time_label).to eq("")
    end
  end

  describe "sequence numbers" do
    let(:roomy) { create(:fliip_service, service_definition: create(:service_definition, paid_sessions: 20, free_sessions: 5)) }
    let!(:first)  { create(:session, fliip_service: roomy, occurred_at: 3.days.ago.change(min: 0)) }
    let!(:second) { create(:session, fliip_service: roomy, occurred_at: 2.days.ago.change(min: 0)) }

    it "counts paid sessions in occurred_at order" do
      expect(first.sequence_number_in_service).to eq(1.0)
      expect(second.sequence_label).to eq("Séance #2")
    end

    it "adds used adjustments that existed before the session" do
      adjustment = create(:service_usage_adjustment, fliip_service: roomy, paid_used_delta: 0.5)
      adjustment.update_columns(created_at: 4.days.ago)
      create(:service_usage_adjustment, fliip_service: roomy, paid_used_delta: 3)

      expect(second.adjustments_used_before_self).to eq(0.5)
      expect(second.sequence_label).to eq("Séance #2.5")
    end

    it "labels absences separately" do
      absence = create(:session, fliip_service: roomy, present: false, occurred_at: 1.day.ago.change(min: 0))

      expect(absence).to be_free
      expect(absence.sequence_label).to eq("Absence #1")
    end

    it "is nil without an occurred_at" do
      expect(build(:session, occurred_at: nil).sequence_label).to be_nil
    end
  end

  describe "#outcome and #outcome_label" do
    it "is Présent·e when present, -24h when charged while absent, Absence when an absence was used" do
      expect(build_session(session_type: :paid, present: true).outcome).to eq(:chargee)
      expect(build_session(session_type: :paid, present: false).outcome).to eq(:moins24)
      expect(build_session(session_type: :free, present: false).outcome).to eq(:absence)

      expect(build_session(session_type: :paid, present: true).outcome_label).to eq("Présent·e")
      expect(build_session(session_type: :paid, present: false).outcome_label).to eq("-24h")
      expect(build_session(session_type: :free, present: false).outcome_label).to eq("Absence")
    end
  end

  describe "editing a séance" do
    # definition: 2 paid séances, 1 absence.
    it "keeps a 1 h absence free when cut to 30 min, though no other absence is left" do
      session = create(:session, fliip_service: service, present: false)
      session.update!(duration: 0.5)

      expect(session).to be_free
    end

    it "turns a present séance into an absence when one is left" do
      session = create(:session, fliip_service: service, present: true)
      session.update!(present: false)

      expect(session).to be_free
    end

    it "turns a present séance into a -24h when no absence is left" do
      create(:session, fliip_service: service, present: false, occurred_at: 2.days.ago.change(min: 0))
      session = create(:session, fliip_service: service, present: true)
      session.update!(present: false)

      expect(session).to be_paid
      expect(session.outcome).to eq(:moins24)
    end

    it "allows 30 min → 1 h when exactly 30 min is left" do
      create(:service_usage_adjustment, fliip_service: service, paid_used_delta: 1.0)
      session = create(:session, fliip_service: service, duration: 0.5)

      expect(session.update(duration: 1.0)).to be(true)
    end

    it "refuses 30 min → 1 h when nothing is left" do
      create(:service_usage_adjustment, fliip_service: service, paid_used_delta: 1.5)
      session = create(:session, fliip_service: service, duration: 0.5)

      expect(session.update(duration: 1.0)).to be(false)
      expect(session.errors[:base]).to include("Aucune séance payante disponible pour ce service.")
    end

    it "gives the séance's own usage back in what is left" do
      absence = create(:session, fliip_service: service, present: false)
      paid = create(:session, fliip_service: service, present: true, occurred_at: 2.days.ago.change(min: 0))

      expect(absence.free_left_excluding_self).to eq(1.0)
      expect(absence.paid_left_excluding_self).to eq(1.0)
      expect(paid.paid_left_excluding_self).to eq(2.0)
    end

    it "doesn't recalculate on a note-only change" do
      session = create(:session, fliip_service: service, present: false)
      definition.update!(free_sessions: 0)

      expect(session.update(note: "Nouvelle note")).to be(true)
      expect(session.reload).to be_free
    end
  end

  describe "#duration_short" do
    it "shows hours and minutes" do
      expect(build_session(duration: 1.0).duration_short).to eq("1 h")
      expect(build_session(duration: 0.5).duration_short).to eq("30 min")
      expect(build_session(duration: 1.5).duration_short).to eq("1 h 30")
    end
  end
end
