require "rails_helper"

RSpec.describe StaffActivity do
  before { travel_to Time.zone.local(2026, 11, 26, 12, 0) }

  let(:trainer) { create(:user) }
  let(:period) { PayPeriod.containing(Date.new(2026, 11, 22)) }
  let(:service) { create(:fliip_service, service_definition: create(:service_definition, paid_sessions: 20, free_sessions: 5)) }

  def seance(time, **attrs)
    create(:session, fliip_service: service, user: trainer, **attrs).tap { |s| s.update_columns(occurred_at: time) }
  end

  it "keeps the trainer's séances and consultations of the period, oldest first" do
    later = seance(Time.zone.local(2026, 11, 25, 9, 0))
    earlier = seance(Time.zone.local(2026, 11, 22, 0, 0))
    seance(Time.zone.local(2026, 11, 21, 23, 59))
    create(:session, fliip_service: service, user: create(:user))
    consultation = create(:consultation, user: trainer, occurred_at: Time.zone.local(2026, 12, 5, 23, 0))

    activity = described_class.new(trainer, period)

    expect(activity.sessions).to eq([ earlier, later ])
    expect(activity.consultations).to eq([ consultation ])
  end

  it "totals séances by outcome and hours, consultations by presence, and the confirmed ones" do
    seance(Time.zone.local(2026, 11, 23, 9, 0), duration: 0.5)
    seance(Time.zone.local(2026, 11, 23, 11, 0), present: false)
    seance(Time.zone.local(2026, 11, 24, 9, 0)).update_columns(present: false, session_type: "paid", confirmed: true)
    create(:consultation, user: trainer, occurred_at: Time.zone.local(2026, 11, 24, 9, 0), present: true, confirmed: true)

    totals = described_class.new(trainer, period).totals

    expect(totals).to have_attributes(chargees: 1, absences: 1, moins24: 1, hours: 2.5,
                                      consultations_present: 1, consultations_absent: 0,
                                      sessions_confirmed: 1, consultations_confirmed: 1)
  end
end
