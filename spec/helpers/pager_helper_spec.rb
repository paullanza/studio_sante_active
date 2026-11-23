require "rails_helper"

RSpec.describe PagerHelper, type: :helper do
  describe "#pager_series" do
    it "lists every page when they fit" do
      expect(helper.pager_series(2, 5)).to eq([ 1, 2, 3, 4, 5 ])
    end

    it "keeps the current page in the middle with gaps on both sides" do
      expect(helper.pager_series(6, 41)).to eq([ 1, :gap, 5, 6, 7, :gap, 41 ])
    end

    it "has no gap at the start near the first page" do
      expect(helper.pager_series(1, 41)).to eq([ 1, 2, 3, 4, 5, :gap, 41 ])
      expect(helper.pager_series(4, 41)).to eq([ 1, 2, 3, 4, 5, :gap, 41 ])
    end

    it "has no gap at the end near the last page" do
      expect(helper.pager_series(41, 41)).to eq([ 1, :gap, 37, 38, 39, 40, 41 ])
    end
  end
end
