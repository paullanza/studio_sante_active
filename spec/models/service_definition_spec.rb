require "rails_helper"

RSpec.describe ServiceDefinition, type: :model do
  describe "validations" do
    subject { build(:service_definition) }

    it { is_expected.to validate_presence_of(:service_id) }
    it { is_expected.to validate_uniqueness_of(:service_id) }
    it { is_expected.to validate_numericality_of(:paid_sessions).only_integer.is_greater_than_or_equal_to(0).allow_nil }
    it { is_expected.to validate_numericality_of(:free_sessions).only_integer.is_greater_than_or_equal_to(0).allow_nil }
  end

  it "links to services through service_id" do
    definition = create(:service_definition)
    service = create(:fliip_service, service_definition: definition)

    expect(definition.fliip_services).to contain_exactly(service)
  end

  describe ".ensure_for!" do
    it "creates a 0/0 definition for each service type among these services that has none" do
      known = create(:service_definition, paid_sessions: 8)
      services = [
        build(:fliip_service, service_definition: known),
        build(:fliip_service, :without_definition, service_id: 7_001, service_name: "Pilates"),
        build(:fliip_service, :without_definition, service_id: 7_001, service_name: "Pilates")
      ]

      expect(described_class.ensure_for!(services)).to eq(1)
      expect(described_class.find_by!(service_id: 7_001)).to have_attributes(service_name: "Pilates", paid_sessions: 0, free_sessions: 0)
      expect(known.reload.paid_sessions).to eq(8)
    end
  end
end
