require "rails_helper"

RSpec.describe ServiceUsageAdjustment, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:fliip_service) }
    it { is_expected.to belong_to(:user) }
    it { is_expected.to have_one(:fliip_user).through(:fliip_service) }
  end

  describe "validations" do
    subject { build(:service_usage_adjustment) }

    it { is_expected.to validate_numericality_of(:paid_used_delta).allow_nil }
    it { is_expected.to validate_numericality_of(:free_used_delta).allow_nil }
    it { is_expected.to validate_numericality_of(:bonus_sessions).allow_nil }

    it "requires at least one non-zero delta" do
      adjustment = build(:service_usage_adjustment, paid_used_delta: 0, free_used_delta: nil, bonus_sessions: 0)

      expect(adjustment).not_to be_valid
      expect(adjustment.errors[:base]).to include("Provide at least one non-zero adjustment.")
    end

    it "accepts a single negative delta" do
      expect(build(:service_usage_adjustment, paid_used_delta: 0, free_used_delta: -0.5)).to be_valid
    end
  end

  describe "delta scopes" do
    let!(:paid)  { create(:service_usage_adjustment, paid_used_delta: 1) }
    let!(:free)  { create(:service_usage_adjustment, paid_used_delta: 0, free_used_delta: 1) }
    let!(:bonus) { create(:service_usage_adjustment, paid_used_delta: 0, bonus_sessions: 2) }

    it "filters by which delta is non-zero" do
      expect(described_class.with_paid_delta).to contain_exactly(paid)
      expect(described_class.with_free_delta).to contain_exactly(free)
      expect(described_class.with_bonus).to contain_exactly(bonus)
    end
  end
end
