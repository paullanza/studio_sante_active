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
end
