require "rails_helper"

RSpec.describe ServiceDefinition, type: :model do
  describe "validations" do
    subject { build(:service_definition) }

    it { is_expected.to validate_presence_of(:service_id) }
    it { is_expected.to validate_uniqueness_of(:service_id) }
    it { is_expected.to validate_numericality_of(:paid_sessions).only_integer.is_greater_than_or_equal_to(0).allow_nil }
    it { is_expected.to validate_numericality_of(:free_sessions).only_integer.is_greater_than_or_equal_to(0).allow_nil }

    it "requires both counts when an allocation is saved" do
      definition = create(:service_definition, paid_sessions: nil, free_sessions: nil)

      expect(definition.update(paid_sessions: 12, free_sessions: nil)).to be(false)
      expect(definition.errors[:free_sessions]).to be_present
      expect(definition.update(paid_sessions: 12, free_sessions: 0)).to be(true)
    end
  end

  describe "#to_define? and .to_define" do
    let!(:unset)   { create(:service_definition, paid_sessions: nil, free_sessions: nil) }
    let!(:partial) { create(:service_definition, paid_sessions: 10, free_sessions: nil) }
    let!(:zero)    { create(:service_definition, paid_sessions: 0, free_sessions: 0) }
    let!(:set)     { create(:service_definition, paid_sessions: 12, free_sessions: 2) }

    it "is true while either count is nil; 0/0 is a real allocation" do
      expect(unset).to be_to_define
      expect(partial).to be_to_define
      expect(zero).not_to be_to_define
      expect(set).not_to be_to_define
    end

    it "lists the allocations to define" do
      expect(described_class.to_define).to contain_exactly(unset, partial)
    end
  end

  describe ".matching" do
    let!(:pilates) { create(:service_definition, service_id: 7_100, service_name: "Pilates 10 séances") }
    let!(:prive)   { create(:service_definition, service_id: 7_200, service_name: "Privé 100% _promo") }

    it "matches part of the name, in any case" do
      expect(described_class.matching("pilates")).to contain_exactly(pilates)
    end

    it "matches the exact DefID when the query is a number" do
      expect(described_class.matching("7200")).to contain_exactly(prive)
      expect(described_class.matching("720")).to be_empty
    end

    it "treats % and _ as plain characters" do
      expect(described_class.matching("100%")).to contain_exactly(prive)
      expect(described_class.matching("_p")).to contain_exactly(prive)
      expect(described_class.matching("%")).to contain_exactly(prive)
    end

    it "returns everything for a blank query" do
      expect(described_class.matching(" ")).to contain_exactly(pilates, prive)
    end
  end

  it "links to services through service_id" do
    definition = create(:service_definition)
    service = create(:fliip_service, service_definition: definition)

    expect(definition.fliip_services).to contain_exactly(service)
  end

  describe ".ensure_for!" do
    it "creates an « à définir » definition for each service type among these services that has none" do
      known = create(:service_definition, paid_sessions: 8)
      services = [
        build(:fliip_service, service_definition: known),
        build(:fliip_service, :without_definition, service_id: 7_001, service_name: "Pilates"),
        build(:fliip_service, :without_definition, service_id: 7_001, service_name: "Pilates")
      ]

      expect(described_class.ensure_for!(services)).to eq(1)
      expect(described_class.find_by!(service_id: 7_001)).to have_attributes(service_name: "Pilates", paid_sessions: nil, free_sessions: nil)
      expect(known.reload.paid_sessions).to eq(8)
    end
  end
end
