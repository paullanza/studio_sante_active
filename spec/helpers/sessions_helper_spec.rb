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
end
