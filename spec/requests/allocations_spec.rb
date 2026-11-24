require "rails_helper"

RSpec.describe "Allocations", type: :request do
  let!(:to_define) { create(:service_definition, service_id: 7_001, service_name: "Pilates 10 séances", paid_sessions: nil, free_sessions: nil) }
  let!(:defined)   { create(:service_definition, service_id: 7_002, service_name: "Privé 12 mois", paid_sessions: 48, free_sessions: 4) }

  let(:turbo) { { "Accept" => "text/vnd.turbo-stream.html, text/html" } }

  describe "access" do
    %i[admin super_admin].each do |role|
      it "lets a#{'n' if role == :admin} #{role} in" do
        sign_in create(:user, role)

        get allocations_path
        expect(response).to have_http_status(:ok)
        get allocation_path(defined)
        expect(response).to have_http_status(:ok)
      end
    end

    %i[employee manager].each do |role|
      it "turns a#{'n' if role == :employee} #{role} away without saving" do
        sign_in(role == :employee ? create(:user) : create(:user, role))

        get allocations_path
        expect(response).to redirect_to(authenticated_root_path)
        get allocation_path(defined)
        expect(response).to redirect_to(authenticated_root_path)
        patch allocation_path(defined), params: { service_definition: { paid_sessions: 1, free_sessions: 1 } }
        expect(response).to redirect_to(authenticated_root_path)
        expect(defined.reload.paid_sessions).to eq(48)
      end
    end
  end

  context "as an admin" do
    before { sign_in create(:user, :admin) }

    describe "GET /allocations" do
      it "lists « à définir » first, then the defined allocations" do
        get allocations_path

        expect(response.body).to include("À définir (1)", "Définies (1)")
        expect(response.body.index("Pilates 10 séances")).to be < response.body.index("Privé 12 mois")
      end

      it "searches by name or DefID" do
        get allocations_path, params: { q: "privé" }
        expect(response.body).to include("Privé 12 mois")
        expect(response.body).not_to include("Pilates 10 séances")

        get allocations_path, params: { q: "7001" }
        expect(response.body).to include("Pilates 10 séances")
        expect(response.body).not_to include("Privé 12 mois")
      end
    end

    describe "PATCH /allocations/:id" do
      it "sets an allocation, which moves it out of « à définir »" do
        patch allocation_path(to_define), params: { service_definition: { paid_sessions: 10, free_sessions: 2 } }, headers: turbo

        expect(to_define.reload).to have_attributes(paid_sessions: 10, free_sessions: 2)
        expect(response.media_type).to eq(Mime[:turbo_stream])
        expect(response.body).to include(%(target="allocation-sections"), "À définir (0)", "Définies (2)")
      end

      it "replaces only the row when the allocation was already set" do
        patch allocation_path(defined), params: { service_definition: { paid_sessions: 96, free_sessions: 4 } }, headers: turbo

        expect(defined.reload.paid_sessions).to eq(96)
        expect(response.body).to include(%(target="service_definition_#{defined.id}"))
        expect(response.body).not_to include(%(target="allocation-sections"))
      end

      it "keeps the allocation and answers 422 when a count is blank" do
        patch allocation_path(defined), params: { service_definition: { paid_sessions: "", free_sessions: 4 } }, headers: turbo

        expect(response).to have_http_status(:unprocessable_content)
        expect(defined.reload.paid_sessions).to eq(48)
      end

      it "ignores attributes other than the two counts" do
        patch allocation_path(defined), params: { service_definition: { paid_sessions: 50, free_sessions: 4, service_name: "Autre", service_id: 1 } }

        expect(defined.reload).to have_attributes(paid_sessions: 50, service_name: "Privé 12 mois", service_id: 7_002)
      end

      it "redirects with a notice without Turbo, keeping the search" do
        patch allocation_path(defined), params: { q: "privé", service_definition: { paid_sessions: 50, free_sessions: 4 } }

        expect(response).to redirect_to(allocations_path(q: "privé"))
        expect(flash[:notice]).to eq("Allocation mise à jour.")
      end
    end

    describe "GET /allocations/:id" do
      it "shows the services of that kind with the active and total counts" do
        client = create(:fliip_user, user_firstname: "Ysolde", user_lastname: "Brisebois")
        create(:fliip_service, service_definition: defined, fliip_user: client)
        create(:fliip_service, service_definition: defined, purchase_status: "I")

        get allocation_path(defined)

        expect(response.body).to include("Ysolde Brisebois", "service actif sur 2")
      end
    end
  end
end
