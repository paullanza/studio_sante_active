require "rails_helper"

RSpec.describe FliipService, type: :model do
  let(:definition) { create(:service_definition, paid_sessions: 10, free_sessions: 2) }
  let(:service)    { create(:fliip_service, service_definition: definition) }

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
end
