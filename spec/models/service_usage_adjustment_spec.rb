require "rails_helper"

RSpec.describe ServiceUsageAdjustment, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:fliip_service) }
    it { is_expected.to belong_to(:user) }
    it { is_expected.to belong_to(:created_by).class_name("User") }
    it { is_expected.to have_one(:fliip_user).through(:fliip_service) }
  end

  describe "validations" do
    def amount_errors(amount)
      build(:service_usage_adjustment, amount: amount).tap(&:validate).errors[:amount]
    end

    it "is valid from the factory, for every kind" do
      described_class.kinds.each_key do |kind|
        expect(build(:service_usage_adjustment, kind: kind)).to be_valid
      end
    end

    it "requires a kind and a note" do
      adjustment = build(:service_usage_adjustment, kind: nil, note: " ")

      expect(adjustment).not_to be_valid
      expect(adjustment.errors[:kind]).to include("doit être choisi")
      expect(adjustment.errors[:note]).to include("est requise")
    end

    it "refuses an unknown kind without raising" do
      expect(build(:service_usage_adjustment, kind: "autre")).not_to be_valid
    end

    it "refuses a missing or zero amount" do
      expect(amount_errors(nil)).to include("est requis")
      expect(amount_errors(0)).to include("doit être différent de 0")
    end

    it "accepts negative amounts in half séances only" do
      expect(build(:service_usage_adjustment, amount: -1.5)).to be_valid
      expect(amount_errors(0.3)).to include("doit être un multiple de 0,5")
    end

    it "caps the note at 1000 characters" do
      expect(build(:service_usage_adjustment, note: "a" * 1001)).not_to be_valid
    end
  end

  describe "#kind_label and #amount_label" do
    it "names the change and signs the amount" do
      adjustment = build(:service_usage_adjustment, kind: :free_bonus, amount: 2)
      expect([ adjustment.kind_label, adjustment.amount_label ]).to eq([ "Absences ajoutées", "+2" ])

      expect(build(:service_usage_adjustment, kind: :paid_used, amount: -0.5).amount_label).to eq("-0,5")
    end
  end
end
