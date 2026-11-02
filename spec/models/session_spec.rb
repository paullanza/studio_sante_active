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

    it "is paid when the service has no definition" do
      service = create(:fliip_service, :without_definition)
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
    it "rejects cancelled services" do
      service.update!(purchase_status: "C")
      session = build_session

      expect(session).not_to be_valid
      expect(session.errors[:base]).to include("Ce service est annulé. Impossible de créer une séance.")
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
    it "confirms only unconfirmed sessions and returns the count" do
      first  = create(:session, fliip_service: service, occurred_at: 1.day.ago)
      second = create(:session, fliip_service: service, occurred_at: 2.days.ago)
      second.update_columns(confirmed: true)

      expect(described_class.confirm([first.id, second.id])).to eq(1)
      expect(first.reload).to be_confirmed
      expect(first.confirmed_at).to be_present
    end

    it "returns 0 for no ids" do
      expect(described_class.confirm([])).to eq(0)
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
    let(:roomy)  { create(:fliip_service, service_definition: create(:service_definition, paid_sessions: 20, free_sessions: 5)) }
    let(:other)  { create(:user) }
    let!(:present_paid) do
      create(:session, fliip_service: roomy, user: staff, present: true, occurred_at: Time.zone.local(2026, 10, 5, 10))
    end
    let!(:absent_free) do
      create(:session, fliip_service: roomy, user: other, present: false, occurred_at: Time.zone.local(2026, 10, 20, 10))
    end

    before { travel_to Time.zone.local(2026, 10, 25, 12) }

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
end
