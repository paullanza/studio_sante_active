require "rails_helper"

RSpec.describe SessionsHelper, type: :helper do
  describe "#default_time_slot_str" do
    def at(hour, min)
      Time.zone.local(2026, 3, 4, hour, min, 17)
    end

    it "rounds down to the half hour" do
      expect(helper.default_time_slot_str(now: at(10, 14))).to eq("10:00")
      expect(helper.default_time_slot_str(now: at(10, 45))).to eq("10:30")
    end

    it "keeps the slot between 06:00 and 20:30" do
      expect(helper.default_time_slot_str(now: at(4, 10))).to eq("06:00")
      expect(helper.default_time_slot_str(now: at(22, 5))).to eq("20:30")
    end
  end

  describe "#outcome_badge_class" do
    it "maps each outcome to its badge" do
      expect(helper.outcome_badge_class(build(:session, session_type: :paid, present: true))).to eq("badge--chargee")
      expect(helper.outcome_badge_class(build(:session, session_type: :paid, present: false))).to eq("badge--moins24")
      expect(helper.outcome_badge_class(build(:session, session_type: :free, present: false))).to eq("badge--absence")
    end
  end

  describe "#seance_datetime" do
    it "shows the French short day, the date and the time" do
      expect(helper.seance_datetime(Time.zone.local(2026, 11, 13, 17, 0))).to eq("ven. 13/11/2026 · 17 h 00")
      expect(helper.seance_datetime(nil)).to eq("—")
    end
  end

  describe "#confirmation_status" do
    it "shows « Non confirmée » until confirmed, then the confirmation date" do
      unconfirmed = Nokogiri::HTML.fragment(helper.confirmation_status(build(:session, confirmed: false))).at_css("span")
      confirmed = build(:session, confirmed: true, confirmed_at: Time.zone.local(2026, 11, 9, 10, 0))

      expect(unconfirmed.text).to eq("Non confirmée")
      expect(unconfirmed["class"]).to eq("text-unconfirmed")
      expect(helper.confirmation_status(confirmed)).to include("Confirmée le 09/11/2026")
      expect(helper.confirmation_status(build(:consultation, confirmed: true, confirmed_at: nil))).to include("Confirmée")
    end
  end

  describe "#seance_outcome_preview" do
    let(:service) { create(:fliip_service, service_definition: create(:service_definition, paid_sessions: 10, free_sessions: 1)) }

    def preview(**attrs)
      helper.seance_outcome_preview(Session.new(fliip_service: service, present: true, duration: 1.0, **attrs))
    end

    it "is Chargée when the client is present" do
      expect(preview).to include(outcome: :chargee, none_left: false, submit_label: "Enregistrer la séance")
    end

    it "uses an absence while one is left, and says how many remain after it" do
      expect(preview(present: false)).to include(outcome: :absence, absences_after: 0.0)
      expect(preview(present: false, duration: 0.5)).to include(outcome: :absence, absences_after: 0.5)
    end

    it "is -24h once the absences are used, with its own button label" do
      create(:service_usage_adjustment, fliip_service: service, free_used_delta: 1)

      expect(preview(present: false)).to include(outcome: :moins24, submit_label: "Enregistrer : -24h, séance déduite")
    end

    it "flags a service without the séances this one needs" do
      create(:service_usage_adjustment, fliip_service: service, paid_used_delta: 9.5)

      expect(preview(duration: 0.5)[:none_left]).to be(false)
      expect(preview[:none_left]).to be(true)
    end

    it "has no outcome without a service" do
      expect(helper.seance_outcome_preview(Session.new(present: true))).to include(outcome: nil, none_left: false)
    end
  end

  describe "#absence_use_line" do
    it "counts the absences left after this one" do
      expect(helper.absence_use_line(1.0, 1.0)).to eq("Utilise 1 absence · 1 restante après celle-ci")
      expect(helper.absence_use_line(0.5, 2.5)).to eq("Utilise 0,5 absence · 2,5 restantes après celle-ci")
    end
  end

  describe "#ticket_day and #ticket_time" do
    it "shows the day and time the way the ticket reads them" do
      expect(helper.ticket_day("2026-11-24")).to eq("mar. 24 nov.")
      expect(helper.ticket_day("pas une date")).to eq("")
      expect(helper.ticket_time("17:00")).to eq("17 h 00")
    end
  end

  describe "absence confirm texts" do
    it "asks to confirm the absence in French" do
      expect(helper.sessions_modal_absence_title).to eq("Confirmer l'absence")
      expect(helper.sessions_modal_moins24_body).to include("-24h", "déduite du forfait")
      expect(helper.sessions_modal_absence_cancel_label).to eq("Revenir")
    end
  end
end
