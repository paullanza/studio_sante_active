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

  describe "#modifiable_by?" do
    let(:owner)   { create(:user) }
    let(:session) { create(:session, fliip_service: service, user: owner) }

    it "lets the owner modify an unconfirmed session" do
      expect(session.modifiable_by?(owner)).to be true
    end

    it "stops the owner once the session is confirmed" do
      session.update_columns(confirmed: true)
      expect(session.modifiable_by?(owner)).to be false
    end

    it "stops other employees and managers" do
      expect(session.modifiable_by?(create(:user))).to be false
      expect(session.modifiable_by?(create(:user, :manager))).to be false
    end

    it "lets admins modify confirmed sessions" do
      session.update_columns(confirmed: true)
      expect(session.modifiable_by?(create(:user, :admin))).to be true
      expect(session.modifiable_by?(create(:user, :super_admin))).to be true
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
end
