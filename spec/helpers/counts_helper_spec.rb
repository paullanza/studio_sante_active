require "rails_helper"

RSpec.describe CountsHelper, type: :helper do
  describe "#format_count" do
    it "drops a trailing zero and uses a French decimal comma" do
      expect(helper.format_count(1.0)).to eq("1")
      expect(helper.format_count(1.5)).to eq("1,5")
      expect(helper.format_count(12)).to eq("12")
      expect(helper.format_count(0.25)).to eq("0,25")
      expect(helper.format_count(nil)).to eq("0")
    end
  end
end
