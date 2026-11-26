require "rails_helper"

RSpec.describe PayPeriod do
  describe ".containing" do
    it "starts the anchor period on the anchor Sunday and ends it on the second Saturday" do
      period = described_class.containing(Date.new(2026, 11, 21))

      expect(period.starts_on).to eq(Date.new(2026, 11, 8))
      expect(period.ends_on).to eq(Date.new(2026, 11, 21))
      expect(period.starts_on).to be_sunday
      expect(period.ends_on).to be_saturday
    end

    it "puts the day before the anchor in the previous period" do
      expect(described_class.containing(Date.new(2026, 11, 7)).starts_on).to eq(Date.new(2026, 10, 25))
    end

    it "finds the period holding 2027-01-01" do
      expect(described_class.containing(Date.new(2027, 1, 1)).range).to eq(Date.new(2026, 12, 20)..Date.new(2027, 1, 2))
    end
  end

  describe "#label" do
    it "names the month on both ends inside a month" do
      expect(described_class.containing(Date.new(2026, 11, 8)).label).to eq("8 nov. au 21 nov. 2026")
    end

    it "names both months across a month" do
      expect(described_class.containing(Date.new(2026, 11, 22)).label).to eq("22 nov. au 5 déc. 2026")
    end

    it "names both years across a year" do
      period = described_class.new(Date.new(2026, 12, 27))

      expect(period.label).to eq("27 déc. 2026 au 9 janv. 2027")
    end
  end

  describe ".from_param" do
    let(:today) { Date.new(2026, 11, 26) }

    it "reads the period's start date" do
      expect(described_class.from_param("2026-11-08", today: today).starts_on).to eq(Date.new(2026, 11, 8))
    end

    it "falls back to the current period on garbage or nothing" do
      expect(described_class.from_param("n'importe quoi", today: today).starts_on).to eq(Date.new(2026, 11, 22))
      expect(described_class.from_param(nil, today: today).starts_on).to eq(Date.new(2026, 11, 22))
    end

    it "round-trips through to_param" do
      period = described_class.containing(Date.new(2026, 3, 3))

      expect(described_class.from_param(period.to_param)).to eq(period)
    end
  end

  it "lists recent periods, the current one first" do
    periods = described_class.recent(3, today: Date.new(2026, 11, 26))

    expect(periods.map(&:starts_on)).to eq([ Date.new(2026, 11, 22), Date.new(2026, 11, 8), Date.new(2026, 10, 25) ])
    expect(periods.first.previous).to eq(periods.second)
    expect(periods.second.next).to eq(periods.first)
  end
end
