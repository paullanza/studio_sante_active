require "rails_helper"

RSpec.describe StaffOverview do
  # Thursday 26 Nov 2026: the period 22 Nov – 5 Dec; the week began Monday 23 Nov.
  before { travel_to Time.zone.local(2026, 11, 26, 12, 0) }

  let(:trainer) { create(:user) }
  let(:period) { PayPeriod.current }
  let(:service) do
    create(:fliip_service, purchase_status: "A", expire_date: 20.days.from_now.to_date,
                           service_definition: create(:service_definition, paid_sessions: 200, free_sessions: 50))
  end

  def seance(time, **attrs)
    create(:session, fliip_service: service, user: trainer, **attrs).tap { |s| s.update_columns(occurred_at: time) }
  end

  def row
    described_class.new([ trainer ], period).rows.first
  end

  it "counts the period's séances by outcome, hours, consultations and sales" do
    seance(Time.zone.local(2026, 11, 23, 9, 0))
    seance(Time.zone.local(2026, 11, 23, 10, 0), duration: 0.5)
    seance(Time.zone.local(2026, 11, 24, 9, 0), present: false)
    seance(Time.zone.local(2026, 11, 20, 9, 0))
    create(:consultation, user: trainer, occurred_at: Time.zone.local(2026, 11, 24, 15, 0))
    create(:consultation, user: trainer, occurred_at: Time.zone.local(2026, 11, 25, 15, 0)).update_columns(fliip_service_id: service.id)

    expect(row).to have_attributes(chargees: 2, absences: 1, moins24: 0, hours: 2.5, consultations: 2, sales: 1)
  end

  it "counts active clients and the services ending within 30 days" do
    seance(Time.zone.local(2026, 11, 23, 9, 0))
    later = create(:fliip_service, purchase_status: "A", fliip_user: service.fliip_user, expire_date: 90.days.from_now.to_date)
    create(:service_usage_adjustment, fliip_service: later, user: trainer)
    ended = create(:fliip_service, purchase_status: "I", expire_date: 5.days.from_now.to_date)
    create(:service_usage_adjustment, fliip_service: ended, user: trainer)

    expect(row).to have_attributes(clients: 1, renewals: 1)
  end

  it "builds the séances-per-week trend, oldest week first" do
    seance(Time.zone.local(2026, 11, 24, 9, 0))
    seance(Time.zone.local(2026, 11, 17, 9, 0))
    seance(Time.zone.local(2026, 11, 18, 9, 0))

    expect(row.trend.last(2)).to eq([ 2, 1 ])
    expect(row.trend.size).to eq(8)
  end

  describe "flags" do
    def trend_row(trend, last_days_ago: 1)
      StaffOverview::Row.new(user: trainer, chargees: 0, absences: 0, moins24: 0, hours: 0, consultations: 0, sales: 0,
                             clients: 0, renewals: 0, last_session_at: last_days_ago && last_days_ago.days.ago,
                             unconfirmed: 0, trend: trend)
    end

    it "flags someone who usually trains and hasn't for more than 7 days" do
      expect(trend_row([ 5, 5, 5, 5, 5, 5, 0, 0 ], last_days_ago: 9)).to be_inactive
      expect(trend_row([ 5, 5, 5, 5, 5, 5, 5, 5 ], last_days_ago: 7)).not_to be_inactive
    end

    it "never flags someone who doesn't usually train" do
      expect(trend_row([ 0, 1, 0, 0, 1, 0, 0, 0 ], last_days_ago: 30)).not_to be_inactive
      expect(trend_row([ 0, 0, 0, 0, 0, 0, 0, 0 ], last_days_ago: nil)).not_to be_inactive
    end

    it "flags a falling trend: the last 2 weeks under 70 % of the 6 before" do
      falling = trend_row([ 12, 12, 11, 12, 13, 12, 6, 4 ])
      expect(falling).to be_falling
      expect(falling.falling_label).to eq("12 → 5 / sem.")
      expect(trend_row([ 12, 12, 11, 12, 13, 12, 10, 9 ])).not_to be_falling
      expect(trend_row([ 1, 1, 1, 1, 1, 1, 0, 0 ])).not_to be_falling
    end
  end

  it "lists the alerts biggest first" do
    other = create(:user)
    [ [ trainer, 1 ], [ other, 3 ] ].each do |user, n|
      n.times { create(:service_usage_adjustment, user: user, fliip_service: create(:fliip_service, purchase_status: "A", expire_date: 10.days.from_now.to_date)) }
    end

    alerts = described_class.new([ trainer, other ], period).alerts

    expect(alerts[:renewals].map(&:user)).to eq([ other, trainer ])
  end
end
