require "rails_helper"

RSpec.describe FliipContract, type: :model do
  it { is_expected.to belong_to(:fliip_user) }

  describe "validations" do
    subject { build(:fliip_contract) }

    it { is_expected.to validate_presence_of(:remote_contract_id) }
    it { is_expected.to validate_uniqueness_of(:remote_contract_id) }

    it "is backed by a unique index" do
      existing = create(:fliip_contract)
      copy = build(:fliip_contract, fliip_user: existing.fliip_user, remote_contract_id: existing.remote_contract_id)
      expect { copy.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end

  describe "status scopes" do
    let!(:active)    { create(:fliip_contract) }
    let!(:inactive)  { create(:fliip_contract, :inactive) }
    let!(:cancelled) { create(:fliip_contract, :cancelled) }
    let!(:stopped)   { create(:fliip_contract, :stopped) }
    let!(:unknown)   { create(:fliip_contract, status: nil) }

    it "filters by status code" do
      expect(described_class.active).to contain_exactly(active)
      expect(described_class.inactive).to contain_exactly(inactive)
      expect(described_class.cancelled).to contain_exactly(cancelled)
      expect(described_class.stopped).to contain_exactly(stopped)
      expect(described_class.unknown).to contain_exactly(unknown)
    end
  end

  describe "#status_name" do
    it "translates each known code" do
      expect(described_class::STATUS_MAP).to eq(
        "A" => "Actif", "I" => "Inactif", "C" => "Annulé", "S" => "Suspendu"
      )
      described_class::STATUS_MAP.each do |code, name|
        expect(build(:fliip_contract, status: code).status_name).to eq(name)
      end
    end

    it "falls back to Unknown for a missing or unexpected code" do
      expect(build(:fliip_contract, status: nil).status_name).to eq("Unknown")
      expect(build(:fliip_contract, status: "Z").status_name).to eq("Unknown")
    end
  end
end
