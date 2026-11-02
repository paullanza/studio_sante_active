require "rails_helper"

RSpec.describe FliipUsersHelper, type: :helper do
  let(:service) do
    build(:fliip_service, id: 7, start_date: Date.new(2026, 1, 1), expire_date: Date.new(2026, 1, 11),
                          service_definition: build(:service_definition, paid_sessions: 8))
  end

  describe "#time_progress_percent" do
    it "returns the elapsed share of the service, clamped to 0..100" do
      expect(helper.time_progress_percent(service, today: Date.new(2026, 1, 6))).to eq(50)
      expect(helper.time_progress_percent(service, today: Date.new(2025, 12, 1))).to eq(0)
      expect(helper.time_progress_percent(service, today: Date.new(2026, 5, 1))).to eq(100)
    end

    it "is 0 when dates are missing or reversed" do
      expect(helper.time_progress_percent(build(:fliip_service, start_date: nil))).to eq(0)
      expect(helper.time_progress_percent(build(:fliip_service, start_date: Date.current, expire_date: Date.current))).to eq(0)
    end
  end

  describe "#paid_usage_percent and #paid_usage_label" do
    it "use the paid sum for this service" do
      sums = { [7, "paid"] => 2.0, [7, "free"] => 1.0 }

      expect(helper.paid_usage_percent(service, sums)).to eq(25)
      expect(helper.paid_usage_label(service, sums)).to eq("2.0/8")
    end

    it "handle a service with no allowance or no usage" do
      bare = build(:fliip_service, :without_definition, id: 8)

      expect(helper.paid_usage_percent(bare, {})).to eq(0)
      expect(helper.paid_usage_label(bare, {})).to eq("0.0/—")
      expect(helper.paid_usage_percent(service, { [7, "paid"] => 20.0 })).to eq(100)
    end
  end

  describe "#time_range_label" do
    it "shows both dates or a dash for a missing one" do
      expect(helper.time_range_label(service)).to eq("01/01/2026 → 11/01/2026")
      expect(helper.time_range_label(build(:fliip_service, start_date: nil, expire_date: nil))).to eq("— → —")
    end
  end
end
