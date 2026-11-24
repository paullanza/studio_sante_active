require "rails_helper"

RSpec.describe "Allocations", type: :request do
  let!(:to_define) { create(:service_definition, service_id: 7_001, service_name: "Pilates au sol - 12 mois - 40 visites", paid_sessions: nil, free_sessions: nil) }
  let!(:other_to_define) { create(:service_definition, service_id: 7_003, service_name: "Accès famille et amies", paid_sessions: nil, free_sessions: nil) }
  let!(:defined) { create(:service_definition, service_id: 7_002, service_name: "Ent. privé - 12 mois - 1x/sem.", paid_sessions: 48, free_sessions: 2) }

  def bulk(allocations, **extra)
    patch bulk_update_allocations_path, params: { allocations: allocations }.merge(extra)
  end

  describe "access" do
    %i[admin super_admin].each do |role|
      it "lets a#{'n' if role == :admin} #{role} in" do
        sign_in create(:user, role)

        get allocations_path
        expect(response).to have_http_status(:ok)
        get allocations_path(corriger: 1)
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
        bulk({ defined.id => { paid_sessions: 1, free_sessions: 1 } })
        expect(response).to redirect_to(authenticated_root_path)
        expect(defined.reload.paid_sessions).to eq(48)
      end
    end
  end

  context "as an admin" do
    before { sign_in create(:user, :admin) }

    describe "GET /allocations" do
      it "shows the queue with inputs and the defined allocations read-only" do
        get allocations_path

        expect(response.body).to include("À définir (2)", "Définies (1)", "40 séances suggérées")
        expect(response.body).to include(%(name="allocations[#{to_define.id}][paid_sessions]"))
        expect(response.body).not_to include(%(name="allocations[#{defined.id}][paid_sessions]"))
      end

      it "turns the defined allocations into inputs in « Mode correction »" do
        get allocations_path(corriger: 1)

        expect(response.body).to include(%(name="allocations[#{defined.id}][paid_sessions]"), "Enregistrer les corrections")
      end

      it "searches by name or DefID" do
        get allocations_path, params: { q: "privé" }
        expect(response.body).to include("Ent. privé - 12 mois - 1x/sem.")
        expect(response.body).not_to include("Pilates au sol")

        get allocations_path, params: { q: "7001" }
        expect(response.body).to include("Pilates au sol")
        expect(response.body).not_to include("Ent. privé - 12 mois")
      end
    end

    describe "PATCH /allocations (the queue)" do
      it "saves the filled entries together and leaves blank ones « à définir »" do
        bulk({ to_define.id => { paid_sessions: "40", free_sessions: "2" }, other_to_define.id => { paid_sessions: "", free_sessions: "" } }, mode: "queue")

        expect(to_define.reload).to have_attributes(paid_sessions: 40, free_sessions: 2)
        expect(other_to_define.reload).to be_to_define
        expect(response).to redirect_to(allocations_path)
        expect(response).to have_http_status(:see_other)
        expect(flash[:notice]).to eq("1 allocation enregistrée.")
      end

      it "saves nothing and answers 422 when an entry has one count only" do
        bulk({ to_define.id => { paid_sessions: "40", free_sessions: "2" }, other_to_define.id => { paid_sessions: "5", free_sessions: "" } }, mode: "queue")

        expect(response).to have_http_status(:unprocessable_content)
        expect(to_define.reload).to be_to_define
        expect(other_to_define.reload).to be_to_define
      end

      it "says so when nothing was filled in" do
        bulk({ to_define.id => { paid_sessions: "", free_sessions: "" } }, mode: "queue", q: "pilates")

        expect(response).to redirect_to(allocations_path(q: "pilates"))
        expect(flash[:notice]).to eq("Aucune modification.")
      end
    end

    describe "PATCH /allocations (corrections)" do
      it "writes only the allocations that changed" do
        untouched = create(:service_definition, paid_sessions: 12, free_sessions: 1)

        expect {
          bulk({ defined.id => { paid_sessions: "52", free_sessions: "2" }, untouched.id => { paid_sessions: "12", free_sessions: "1" } }, mode: "correction")
        }.not_to(change { untouched.reload.updated_at })

        expect(defined.reload.paid_sessions).to eq(52)
        expect(flash[:notice]).to eq("1 correction enregistrée.")
      end

      it "refuses to blank a defined allocation, stays in correction mode and answers 422" do
        bulk({ defined.id => { paid_sessions: "", free_sessions: "2" } }, mode: "correction")

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include("Enregistrer les corrections")
        expect(defined.reload.paid_sessions).to eq(48)
      end

      it "ignores attributes other than the two counts, and unknown ids" do
        bulk({ defined.id => { paid_sessions: "50", free_sessions: "2", service_name: "Autre", service_id: "1" }, "0" => { paid_sessions: "1", free_sessions: "1" } }, mode: "correction")

        expect(defined.reload).to have_attributes(paid_sessions: 50, service_name: "Ent. privé - 12 mois - 1x/sem.", service_id: 7_002)
      end
    end

    describe "GET /allocations/:id" do
      it "shows the services of that kind with the active and total counts" do
        client = create(:fliip_user, user_firstname: "Ysolde", user_lastname: "Brisebois")
        create(:fliip_service, service_definition: defined, fliip_user: client)
        create(:fliip_service, service_definition: defined, purchase_status: "I")

        get allocation_path(defined)

        expect(response.body).to include("Ysolde Brisebois", "service actif sur 2")
        expect(response.body).to include(ERB::Util.html_escape(allocations_path(q: defined.service_id, corriger: 1)))
      end
    end
  end
end
