require "rails_helper"

RSpec.describe CsvPorter::Base do
  let(:porter) { described_class.new }

  it "#csv_generate writes the header row first" do
    csv = porter.send(:csv_generate, %w[a b]) { |rows| rows << [1, "x, y"] }

    expect(CSV.parse(csv)).to eq([%w[a b], ["1", "x, y"]])
  end

  it "#csv_safe_date uses dd/mm/yyyy and blanks a missing date" do
    expect(porter.send(:csv_safe_date, Date.new(2026, 3, 4))).to eq("04/03/2026")
    expect(porter.send(:csv_safe_date, nil)).to be_nil
  end

  it "#parse_date reads dd/mm/yyyy first, then other formats" do
    expect(porter.send(:parse_date, "04/03/2026")).to eq(Date.new(2026, 3, 4))
    expect(porter.send(:parse_date, " 2026-03-04 ")).to eq(Date.new(2026, 3, 4))
    expect(porter.send(:parse_date, "")).to be_nil
    expect(porter.send(:parse_date, "31/02/2026")).to be_nil
    expect(porter.send(:parse_date, "nope")).to be_nil
  end

  it "#norm_name lowercases, trims and drops accents" do
    expect(porter.send(:norm_name, "  Éloïse Côté ")).to eq("eloise cote")
  end

  it "#to_f_or_zero falls back to 0.0" do
    expect(porter.send(:to_f_or_zero, " 1.5 ")).to eq(1.5)
    expect(porter.send(:to_f_or_zero, "")).to eq(0.0)
    expect(porter.send(:to_f_or_zero, "abc")).to eq(0.0)
  end
end
