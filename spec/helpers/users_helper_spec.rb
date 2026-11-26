require "rails_helper"

RSpec.describe UsersHelper, type: :helper do
  def row(**attrs)
    StaffOverview::Row.new(**{ user: build(:user), chargees: 2, absences: 1, moins24: 1, hours: 4.0, consultations: 0,
                               sales: 0, clients: 0, renewals: 0, last_session_at: nil, unconfirmed: 0,
                               trend: [ 0, 2, 4 ] }.merge(attrs))
  end

  it "draws the outcome bar in proportion, with a label" do
    svg = Nokogiri::HTML.fragment(helper.outcome_bar(row))

    expect(svg.css("rect").map { |r| r["width"].to_f }).to eq([ 50.0, 25.0, 25.0 ])
    expect(svg.at_css("svg")["aria-label"]).to eq("2 présent·e, 1 absence, 1 -24h")
  end

  it "draws one bar a week, the latest marked" do
    svg = Nokogiri::HTML.fragment(helper.trend_sparkline([ 0, 2, 4 ]))

    expect(svg.css("rect").size).to eq(3)
    expect(svg.css("rect").last["class"]).to include("trend__bar--now")
  end

  it "says when the last séance was, and how many consultations sold" do
    travel_to Time.zone.local(2026, 11, 26, 12, 0)

    expect(helper.last_session_label(row(last_session_at: nil))).to eq("jamais")
    expect(helper.last_session_label(row(last_session_at: 1.day.ago))).to eq("hier")
    expect(helper.last_session_label(row(last_session_at: 9.days.ago))).to eq("il y a 9 j")
    expect(helper.sales_label(row(consultations: 3, sales: 2))).to eq("2 vendues")
    expect(helper.sales_label(row)).to eq("—")
  end
end
