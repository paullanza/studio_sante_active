require "rails_helper"

RSpec.describe FliipService, type: :model do
  let(:definition) { create(:service_definition, paid_sessions: 10, free_sessions: 2) }
  let(:service)    { create(:fliip_service, service_definition: definition) }

  describe "validations" do
    subject { build(:fliip_service) }

    it { is_expected.to validate_presence_of(:remote_purchase_id) }
    it { is_expected.to validate_uniqueness_of(:remote_purchase_id) }

    it "is backed by a unique index" do
      existing = create(:fliip_service)
      copy = build(:fliip_service, fliip_user: existing.fliip_user, service_definition: existing.service_definition, remote_purchase_id: existing.remote_purchase_id)
      expect { copy.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end

  describe "usage totals" do
    it "starts with the full allowance remaining" do
      expect(service.remaining_paid_sessions).to eq(10.0)
      expect(service.remaining_free_sessions).to eq(2.0)
    end

    it "counts session durations against the matching allowance" do
      create(:session, fliip_service: service, present: true, duration: 1.0)
      create(:session, fliip_service: service, present: true, duration: 0.5,
                       occurred_at: 1.day.ago)
      create(:session, fliip_service: service, present: false, duration: 1.0,
                       occurred_at: 2.days.ago)

      expect(service.paid_used_total).to eq(1.5)
      expect(service.free_used_total).to eq(1.0)
      expect(service.remaining_paid_sessions).to eq(8.5)
      expect(service.remaining_free_sessions).to eq(1.0)
    end

    it "adds bonus sessions to the paid allowance" do
      create(:service_usage_adjustment, fliip_service: service, bonus_sessions: 3)

      expect(service.paid_allowed_total).to eq(13.0)
      expect(service.remaining_paid_sessions).to eq(13.0)
    end

    it "applies used deltas from adjustments" do
      create(:service_usage_adjustment, fliip_service: service, paid_used_delta: 4, free_used_delta: 1)

      expect(service.paid_used_total).to eq(4.0)
      expect(service.remaining_paid_sessions).to eq(6.0)
      expect(service.remaining_free_sessions).to eq(1.0)
    end

    it "never goes below zero remaining" do
      create(:service_usage_adjustment, fliip_service: service, paid_used_delta: 15)

      expect(service.remaining_paid_sessions).to eq(0.0)
      expect(service).to be_fully_used
    end

    it "returns nil remaining when the service has no definition" do
      service = create(:fliip_service, :without_definition)

      expect(service.remaining_paid_sessions).to be_nil
      expect(service.remaining_free_sessions).to be_nil
    end
  end

  describe "#booking_block_reason" do
    it "is nil for a current active service with sessions left" do
      expect(service.booking_block_reason).to be_nil
    end

    it "blocks cancelled services" do
      service.update!(purchase_status: "C")
      expect(service.booking_block_reason).to eq("Annulé")
    end

    it "blocks services missing from Fliip, before any other reason" do
      service.update!(purchase_status: "C", missing_from_fliip_at: 1.day.ago)
      expect(service.booking_block_reason).to eq("Retiré de Fliip")
    end

    it "blocks services whose client is missing from Fliip" do
      service.fliip_user.update!(missing_from_fliip_at: 1.day.ago)
      expect(service.booking_block_reason).to eq("Retiré de Fliip")
    end

    it "blocks services starting more than 30 days from now" do
      service.update!(start_date: 31.days.from_now.to_date)
      expect(service.booking_block_reason).to eq("Commence dans plus de 30 jours")
    end

    it "blocks services that ended more than 30 days ago" do
      service.update!(start_date: 1.year.ago.to_date, expire_date: 31.days.ago.to_date)
      expect(service.booking_block_reason).to eq("Terminé il y a plus de 30 jours")
    end

    it "blocks fully used services" do
      create(:service_usage_adjustment, fliip_service: service, paid_used_delta: 10)
      expect(service.booking_block_reason).to eq("Toutes les séances utilisées")
    end
  end

  describe ".current" do
    it "includes active services within their dates only" do
      current = service
      expired = create(:fliip_service, expire_date: 1.day.ago.to_date)
      inactive = create(:fliip_service, purchase_status: "I")

      expect(described_class.current).to include(current)
      expect(described_class.current).not_to include(expired, inactive)
    end
  end

  describe "status scopes and names" do
    it "filters by purchase status" do
      by_code = %w[A I P C S].index_with { |code| create(:fliip_service, purchase_status: code) }

      expect(described_class.active).to contain_exactly(by_code["A"])
      expect(described_class.inactive).to contain_exactly(by_code["I"])
      expect(described_class.planned).to contain_exactly(by_code["P"])
      expect(described_class.cancelled).to contain_exactly(by_code["C"])
      expect(described_class.stopped).to contain_exactly(by_code["S"])
      expect(described_class.by_statuses(%w[A S])).to contain_exactly(by_code["A"], by_code["S"])
      expect(described_class.by_statuses([]).count).to eq(5)
    end

    it "#status_name translates the code" do
      expect(build(:fliip_service, purchase_status: "P").status_name).to eq("Planifié")
      expect(build(:fliip_service, purchase_status: "Z").status_name).to be_nil
    end
  end

  describe "association helpers" do
    let(:client) { create(:fliip_user) }
    let(:base)   { Date.new(2026, 6, 15) }

    it ".purchase_within_association_window uses purchase date, then start date, from -14 to +30 days" do
      inside   = create(:fliip_service, fliip_user: client, purchase_date: base - 14, start_date: base - 100)
      fallback = create(:fliip_service, fliip_user: client, purchase_date: nil, start_date: base + 30)
      create(:fliip_service, fliip_user: client, purchase_date: base + 31)

      expect(described_class.purchase_within_association_window(base)).to contain_exactly(inside, fallback)
    end

    it ".start_within_window uses start date, then purchase date, from -14 days to +3 months" do
      inside = create(:fliip_service, fliip_user: client, start_date: base + 3.months)
      create(:fliip_service, fliip_user: client, start_date: base - 15)

      expect(described_class.start_within_window(base)).to contain_exactly(inside)
    end

    it ".available_for_association excludes services already linked to a consultation" do
      free_service  = create(:fliip_service, fliip_user: client, purchase_date: base)
      taken_service = create(:fliip_service, fliip_user: client, purchase_date: base)
      create(:consultation, fliip_service: taken_service)
      create(:fliip_service, purchase_date: base)

      expect(described_class.unassociated_with_consultation).not_to include(taken_service)
      expect(described_class.available_for_association(fliip_user_id: client.id, cutoff_date: base))
        .to contain_exactly(free_service)
      expect(described_class.find_available_for_association(service_id: free_service.id, fliip_user_id: client.id, cutoff_date: base))
        .to eq(free_service)
      expect(described_class.find_available_for_association(service_id: taken_service.id, fliip_user_id: client.id, cutoff_date: base))
        .to be_nil
      expect(described_class.find_available_for_association(service_id: nil, fliip_user_id: client.id, cutoff_date: base))
        .to be_nil
    end

    it "#start_or_purchase_date prefers the start date" do
      expect(build(:fliip_service, start_date: base, purchase_date: base - 5).start_or_purchase_date).to eq(base)
      expect(build(:fliip_service, start_date: nil, purchase_date: Time.zone.local(2026, 6, 10, 12)).start_or_purchase_date).to eq(base - 5)
    end
  end

  describe "booking logic" do
    it "#next_session_type offers free first, then paid, then nothing" do
      expect(service.next_session_type).to eq("free")
      expect(service).to be_can_book_session

      create(:service_usage_adjustment, fliip_service: service, paid_used_delta: 0, free_used_delta: 2)
      expect(service.next_session_type).to eq("paid")

      create(:service_usage_adjustment, fliip_service: service, paid_used_delta: 10)
      expect(service.next_session_type).to be_nil
      expect(service).not_to be_can_book_session
      expect(service).to be_booking_blocked
    end

    it "#usage_stats summarizes both allowances" do
      create(:service_usage_adjustment, fliip_service: service, paid_used_delta: 3, bonus_sessions: 2)

      expect(service.usage_stats).to eq(
        paid: { used_sessions: 3.0, included: 10, bonus: 2.0, allowed_total: 12.0, remaining: 9.0 },
        free: { used_sessions: 0.0, included: 2, allowed_total: 2.0, remaining: 2.0 }
      )
    end
  end

  describe "progress and labels" do
    it "#paid_progress_percent and #free_progress_percent round the used share" do
      create(:service_usage_adjustment, fliip_service: service, paid_used_delta: 2.5, free_used_delta: 1)

      expect(service.paid_progress_percent).to eq(25)
      expect(service.free_progress_percent).to eq(50)
    end

    it "returns nil progress without an allowance" do
      bare = create(:fliip_service, :without_definition)

      expect(bare.paid_progress_percent).to be_nil
      expect(bare.free_progress_percent).to be_nil
    end

    it "#time_progress_percent is clamped between 0 and 100" do
      timed = build(:fliip_service, start_date: Date.new(2026, 1, 1), expire_date: Date.new(2026, 1, 11))

      expect(timed.time_progress_percent(today: Date.new(2026, 1, 6))).to eq(50)
      expect(timed.time_progress_percent(today: Date.new(2025, 12, 1))).to eq(0)
      expect(timed.time_progress_percent(today: Date.new(2026, 3, 1))).to eq(100)
      expect(build(:fliip_service, start_date: nil).time_progress_percent).to be_nil
      expect(build(:fliip_service, start_date: Date.new(2026, 1, 1), expire_date: Date.new(2026, 1, 1)).time_progress_percent).to be_nil
    end

    it "#time_range_label formats both dates" do
      timed = build(:fliip_service, start_date: Date.new(2026, 1, 1), expire_date: Date.new(2026, 2, 1))

      expect(timed.time_range_label).to eq("01/01/2026 – 01/02/2026")
      expect(build(:fliip_service, expire_date: nil).time_range_label).to eq("—")
    end

    it "#paid_breakdown, #paid_usage_compact_str and #absences_compact_str format usage" do
      create(:service_usage_adjustment, fliip_service: service, paid_used_delta: 1.5, bonus_sessions: 2, free_used_delta: 0.5)

      expect(service.paid_breakdown).to include(
        used: 1.5, included: 10, bonus: 2.0, allowed: 12.0, percent: 13,
        used_str: "1.5", included_str: "10", allowed_str: "12.0", percent_str: "13"
      )
      expect(service.paid_usage_compact_str).to eq("1.5/(10.0 + 2.0)")
      expect(service.absences_compact_str).to eq("[0.5/2.0 absences]")
    end

    it "#paid_usage_compact_str omits a zero bonus" do
      expect(service.paid_usage_compact_str).to eq("0.0/10.0")
    end
  end

  describe "#overrun_days and #overrun_label" do
    def spanning(days)
      build(:fliip_service, start_date: Date.new(2026, 10, 26), expire_date: Date.new(2026, 10, 26) + days)
    end

    it "measures spans over 365 days against 12 months" do
      service = build(:fliip_service, start_date: Date.new(2026, 10, 26), expire_date: Date.new(2027, 11, 12))

      expect(service.overrun_days).to eq(17)
      expect(service.overrun_label).to eq("12 mois + 17 j")
      expect(spanning(366).overrun_label).to eq("12 mois + 1 j")
    end

    it "measures spans over 90 days against 3 months" do
      expect(spanning(100).overrun_days).to eq(10)
      expect(spanning(100).overrun_label).to eq("3 mois + 10 j")
    end

    it "is nil for a span of 90 days or less, or a missing date" do
      expect(spanning(90).overrun_days).to be_nil
      expect(spanning(90).overrun_label).to be_nil
      expect(build(:fliip_service, start_date: nil).overrun_label).to be_nil
    end
  end

  describe "#days_left" do
    it "counts the days to the end date, floored at 0" do
      service = build(:fliip_service, expire_date: Date.new(2026, 12, 1))

      expect(service.days_left(Date.new(2026, 11, 24))).to eq(7)
      expect(service.days_left(Date.new(2026, 12, 10))).to eq(0)
      expect(build(:fliip_service, expire_date: nil).days_left).to be_nil
    end
  end

  describe "#allocation_to_define?" do
    it "is true without an allocation, or with 0/0 or nil/nil" do
      expect(build(:fliip_service, :without_definition)).to be_allocation_to_define
      expect(build(:fliip_service, service_definition: build(:service_definition, paid_sessions: 0, free_sessions: 0))).to be_allocation_to_define
      expect(build(:fliip_service, service_definition: build(:service_definition, paid_sessions: nil, free_sessions: nil))).to be_allocation_to_define
    end

    it "is false once either count is set" do
      expect(build(:fliip_service, service_definition: build(:service_definition, paid_sessions: 12, free_sessions: 0))).not_to be_allocation_to_define
      expect(build(:fliip_service, service_definition: build(:service_definition, paid_sessions: 0, free_sessions: 2))).not_to be_allocation_to_define
    end
  end

  describe "#numbered_sessions" do
    let(:roomy) { create(:fliip_service, service_definition: create(:service_definition, paid_sessions: 20, free_sessions: 5)) }

    before { travel_to Time.zone.local(2026, 11, 20, 12, 0) }

    it "numbers every séance in occurred_at order and returns them newest first" do
      first  = create(:session, fliip_service: roomy, occurred_at: Time.zone.local(2026, 11, 10, 9, 0))
      absence = create(:session, fliip_service: roomy, present: false, occurred_at: Time.zone.local(2026, 11, 12, 9, 0))
      third  = create(:session, fliip_service: roomy, occurred_at: Time.zone.local(2026, 11, 14, 9, 0))

      expect(absence).to be_free
      expect(roomy.numbered_sessions).to eq([ [ third, 3 ], [ absence, 2 ], [ first, 1 ] ])
    end

    it "breaks ties on occurred_at by id" do
      at = Time.zone.local(2026, 11, 10, 9, 0)
      first  = create(:session, fliip_service: roomy, occurred_at: at)
      second = create(:session, fliip_service: roomy, occurred_at: at + 1.hour)
      second.update_columns(occurred_at: at) # the uniqueness check only runs through validations

      expect(roomy.numbered_sessions.map(&:first)).to eq([ second, first ])
    end

    it "adds the séances and absences used by adjustments created at or before each séance" do
      early = create(:service_usage_adjustment, fliip_service: roomy, paid_used_delta: 2, free_used_delta: 0.5)
      early.update_columns(created_at: Time.zone.local(2026, 11, 1, 9, 0))
      late = create(:service_usage_adjustment, fliip_service: roomy, paid_used_delta: 3)
      late.update_columns(created_at: Time.zone.local(2026, 11, 13, 9, 0))
      first  = create(:session, fliip_service: roomy, occurred_at: Time.zone.local(2026, 11, 10, 9, 0))
      second = create(:session, fliip_service: roomy, occurred_at: Time.zone.local(2026, 11, 13, 9, 0))

      expect(roomy.numbered_sessions).to eq([ [ second, 7.5 ], [ first, 3.5 ] ])
    end
  end
end
