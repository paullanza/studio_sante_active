require "rails_helper"

RSpec.describe ConsultationsHelper, type: :helper do
  describe "#consultations_modal_disassociate_body" do
    let(:client) { build(:fliip_user, user_firstname: "Léa", user_lastname: "Roy") }

    it "names the client and the service" do
      service = build(:fliip_service, fliip_user: client, service_name: "Pilates")
      consultation = build(:consultation, fliip_user: client, fliip_service: service)

      expect(helper.consultations_modal_disassociate_body(consultation))
        .to eq("Retirer l’association avec « Léa Roy – Pilates » ?")
    end

    it "falls back to the service's client and the service id" do
      service = build(:fliip_service, id: 42, fliip_user: client, service_name: "")
      consultation = build(:consultation, fliip_user: nil, fliip_service: service)

      expect(helper.consultations_modal_disassociate_body(consultation))
        .to eq("Retirer l’association avec « Léa Roy – Service #42 » ?")
    end

    it "names only the client when there is no service" do
      consultation = build(:consultation, fliip_user: client)

      expect(helper.consultations_modal_disassociate_body(consultation))
        .to eq("Retirer l’association avec « Léa Roy » ?")
    end

    it "uses a generic label without a client" do
      expect(helper.consultations_modal_disassociate_body(build(:consultation)))
        .to eq("Retirer l’association avec « cette association » ?")
      expect(helper.consultations_modal_disassociate_body(nil))
        .to eq("Retirer l’association avec « cette association » ?")
    end
  end
end
