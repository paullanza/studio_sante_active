require "rails_helper"

RSpec.describe "Consultations", type: :request do
  let(:employee) { create(:user) }

  def consultation_params(**overrides)
    {
      consultation: {
        first_name: "Jo",
        last_name: "Tremblay",
        phone_number: "514-555-0100",
        date: Date.current.iso8601,
        time: "10:00",
        present: "1"
      }.merge(overrides)
    }
  end

  describe "POST /consultations" do
    it "creates a consultation for the signed-in employee" do
      sign_in employee

      expect { post consultations_path, params: consultation_params }.to change(Consultation, :count).by(1)

      expect(Consultation.last.user).to eq(employee)
      expect(response).to redirect_to(new_seance_path)
    end

    it "re-renders the booking page when a required field is missing" do
      sign_in employee

      expect { post consultations_path, params: consultation_params(phone_number: "") }
        .not_to change(Consultation, :count)
      expect(response).to have_http_status(:unprocessable_content)
      expect(flash[:alert]).to be_present
    end
  end

  describe "GET /consultations/new" do
    it "is no longer routed" do
      expect { Rails.application.routes.recognize_path("/consultations/new", method: :get) }
        .to raise_error(ActionController::RoutingError)
    end
  end

  context "when signed out" do
    it "redirects to sign-in" do
      consultation = create(:consultation)

      post consultations_path, params: consultation_params
      expect(response).to redirect_to(new_user_session_path)
      get edit_consultation_path(consultation)
      expect(response).to redirect_to(new_user_session_path)
      get associations_consultations_path
      expect(response).to redirect_to(new_user_session_path)
    end
  end

  describe "choosing the employee on create" do
    let(:super_admin) { create(:user, :super_admin) }

    it "ignores user_id from employees and managers" do
      manager = create(:user, :manager)

      sign_in employee
      post consultations_path, params: consultation_params(user_id: manager.id)
      expect(Consultation.last.user).to eq(employee)

      sign_in manager
      post consultations_path, params: consultation_params(user_id: employee.id, time: "11:00")
      expect(Consultation.last.user).to eq(manager)
    end

    it "lets admins create for an employee, but never for the super admin" do
      sign_in create(:user, :admin)

      post consultations_path, params: consultation_params(user_id: employee.id)
      expect(Consultation.last.user).to eq(employee)

      expect { post consultations_path, params: consultation_params(user_id: super_admin.id) }
        .not_to change(Consultation, :count)
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "requires the super admin to choose an employee" do
      sign_in super_admin

      expect { post consultations_path, params: consultation_params }.not_to change(Consultation, :count)
      expect(flash[:alert]).to include("Veuillez choisir un·e employé·e.")

      post consultations_path, params: consultation_params(user_id: employee.id)
      expect(Consultation.last).to have_attributes(user: employee, created_by: super_admin)
    end
  end

  describe "editing by role" do
    let(:manager) { create(:user, :manager) }
    let!(:own)    { create(:consultation, user: employee, first_name: "Avant") }
    let!(:confirmed) { create(:consultation, user: employee, confirmed: true) }
    let!(:managers_own) { create(:consultation, user: manager) }

    def update_params(**overrides)
      { consultation: { first_name: "Après", last_name: "Roy", phone_number: "514-555-0100",
                        date: Date.current.iso8601, time: "10:00", present: "1" }.merge(overrides) }
    end

    it "lets employees edit their own unconfirmed consultation only" do
      sign_in employee

      get edit_consultation_path(own)
      expect(response).to have_http_status(:ok)
      patch consultation_path(own), params: update_params(user_id: manager.id)
      expect(own.reload).to have_attributes(first_name: "Après", user: employee)

      get edit_consultation_path(confirmed)
      expect(response).to redirect_to(new_seance_path(tab: "consultation"))
      expect(flash[:alert]).to eq("Non autorisé·e.")
      expect { delete consultation_path(confirmed), headers: { "Accept" => "application/json" } }
        .not_to change(Consultation, :count)
      expect(response).to have_http_status(:forbidden)
    end

    it "lets managers edit only their own" do
      sign_in manager

      patch consultation_path(managers_own), params: update_params
      expect(managers_own.reload.first_name).to eq("Après")
      patch consultation_path(own), params: update_params(first_name: "Manager")
      expect(own.reload.first_name).to eq("Avant")
    end

    it "lets admins and the super admin edit any consultation and reassign it" do
      other = create(:user)

      sign_in create(:user, :admin)
      patch consultation_path(confirmed), params: update_params(user_id: other.id)
      expect(confirmed.reload.user).to eq(other)

      sign_in create(:user, :super_admin)
      expect { delete consultation_path(managers_own) }.to change(Consultation, :count).by(-1)
    end

    it "refuses to reassign a consultation to the super admin" do
      super_admin = create(:user, :super_admin)
      sign_in create(:user, :admin)

      patch consultation_path(own), params: update_params(user_id: super_admin.id)

      expect(response).to have_http_status(:unprocessable_content)
      expect(own.reload.user).to eq(employee)
    end

    it "serves the row to every signed-in user" do
      sign_in create(:user)
      get row_consultation_path(own)

      expect(response).to have_http_status(:ok)
    end
  end

  describe "association" do
    let(:client)  { create(:fliip_user, user_firstname: "Léa", user_lastname: "Roy") }
    let(:service) { create(:fliip_service, fliip_user: client, purchase_date: 1.day.ago) }
    let!(:consultation) do
      create(:consultation, user: employee, first_name: "Léa", last_name: "Roy", occurred_at: Time.current, confirmed: true)
    end

    def associate
      patch associate_consultation_path(consultation), params: { fliip_user_id: client.id, fliip_service_id: service.id }
    end

    it "is closed to employees, even on their own consultation" do
      sign_in employee

      get association_consultation_path(consultation)
      expect(response).to redirect_to(new_seance_path(tab: "consultation"))
      get service_select_consultation_path(consultation, fliip_user_id: client.id)
      expect(response).to have_http_status(:forbidden)
      associate
      expect(consultation.reload.fliip_service).to be_nil
      get associations_consultations_path
      expect(response).to redirect_to(new_seance_path(tab: "consultation"))
    end

    it "lets managers associate any consultation, confirmed or not" do
      sign_in create(:user, :manager)

      get associations_consultations_path
      expect(response).to have_http_status(:ok)
      get association_consultation_path(consultation)
      expect(response).to have_http_status(:ok)
      get service_select_consultation_path(consultation, fliip_user_id: client.id)
      expect(response).to have_http_status(:ok)

      associate

      expect(consultation.reload).to have_attributes(fliip_user: client, fliip_service: service)
    end

    it "refuses a service already linked to another consultation" do
      create(:consultation, fliip_service: service)
      sign_in create(:user, :admin)

      associate

      expect(response).to have_http_status(:unprocessable_content)
      expect(consultation.reload.fliip_service).to be_nil
    end

    it "lets only admins and the super admin disassociate" do
      consultation.update!(fliip_user: client, fliip_service: service)

      [employee, create(:user, :manager)].each do |user|
        sign_in user
        patch disassociate_consultation_path(consultation)
        expect(consultation.reload.fliip_service).to eq(service)
      end

      sign_in create(:user, :super_admin)
      patch disassociate_consultation_path(consultation)

      expect(consultation.reload.fliip_service).to be_nil
      expect(response).to redirect_to(new_seance_path(tab: "consultation"))
      expect(flash[:notice]).to eq("Association retirée.")
    end

    it "leaves the super admin out of the associations employee filter" do
      super_admin = create(:user, :super_admin)
      sign_in create(:user, :manager)

      get associations_consultations_path

      # The filter options are only visible in the markup.
      expect(response.body).to include(%(value="#{employee.id}"))
      expect(response.body).not_to include(%(value="#{super_admin.id}"))
    end
  end

  describe "PATCH /admin/confirm_consultations" do
    let!(:consultation) { create(:consultation) }

    it "lets admins confirm and refuses managers" do
      sign_in create(:user, :manager)
      patch admin_confirm_consultations_path, params: { consultation_ids: [consultation.id] }
      expect(consultation.reload).not_to be_confirmed

      sign_in create(:user, :admin)
      patch admin_confirm_consultations_path, params: { consultation_ids: [consultation.id] }
      expect(consultation.reload).to be_confirmed
    end
  end
end
