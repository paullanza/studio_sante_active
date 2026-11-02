require "rails_helper"

RSpec.describe Consultation, type: :model do
  describe "validations" do
    it "allows a service to be linked to only one consultation" do
      service = create(:fliip_service)
      create(:consultation, fliip_service: service)
      other = build(:consultation, fliip_service: service)

      expect(other).not_to be_valid
      expect(other.errors[:fliip_service_id]).to be_present
    end

    it "defaults created_by to the responsible user" do
      consultation = create(:consultation)
      expect(consultation.created_by).to eq(consultation.user)
    end
  end

  describe ".confirm" do
    it "confirms unconfirmed consultations" do
      consultation = create(:consultation)

      expect(described_class.confirm([consultation.id])).to eq(1)
      expect(consultation.reload).to be_confirmed
    end
  end
end
