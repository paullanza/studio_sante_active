require "rails_helper"

RSpec.describe ProgressHelper, type: :helper do
  describe "#progress_base_color" do
    it "is grey at 100% and blue below" do
      expect(helper.progress_base_color(100)).to eq("bg-secondary")
      expect(helper.progress_base_color(99)).to eq("bg-primary")
    end
  end

  describe "#progress_discrepancy_color" do
    it "warns more strongly as sessions fall behind time" do
      expect(helper.progress_discrepancy_color(50, 64)).to be_nil
      expect(helper.progress_discrepancy_color(50, 65)).to eq("bg-warning")
      expect(helper.progress_discrepancy_color(50, 75)).to eq("bg-orange")
      expect(helper.progress_discrepancy_color(50, 90)).to eq("bg-danger")
    end
  end

  describe "#progress_usage_color" do
    it "prefers the discrepancy color over the base color" do
      expect(helper.progress_usage_color(10, 60)).to eq("bg-danger")
      expect(helper.progress_usage_color(60, 60)).to eq("bg-primary")
    end
  end

  describe "#bar_with_label" do
    it "renders the fill width, label and a readable text tone" do
      html = Nokogiri::HTML.fragment(helper.bar_with_label(percent: 42, label: "4/10", bg_class: "bg-warning"))

      expect(html.at_css(".progress")["aria-valuenow"]).to eq("42")
      expect(html.at_css(".progress-bar")["style"]).to eq("width:42%")
      expect(html.at_css(".progress-label").text).to eq("4/10")
      expect(html.at_css(".progress-label")["class"]).to include("label-dark")
    end

    it "defaults to the base color with light text" do
      html = Nokogiri::HTML.fragment(helper.bar_with_label(percent: 30, label: "x"))

      expect(html.at_css(".progress-bar")["class"]).to include("bg-primary")
      expect(html.at_css(".progress-label")["class"]).to include("label-light")
    end
  end
end
