require "rails_helper"

RSpec.describe "Admin", type: :request do
  let(:definition)   { create(:service_definition, paid_sessions: 4) }
  let(:signup_code)  { create(:signup_code) }
  let(:session_record) { create(:session) }
  let(:consultation) { create(:consultation) }

  # Every admin route with a request that should succeed for admins.
  def admin_requests
    {
      "dashboard"                 => -> { get admin_dashboard_path },
      "services"                  => -> { get admin_services_path },
      "service_show"              => -> { get admin_service_path(definition) },
      "update_service"            => -> { patch update_admin_service_path(definition), params: { paid_sessions: 6, free_sessions: 1 } },
      "client_services"           => -> { get "/admin/client_services" },
      "import_clients"            => -> { post import_clients_path },
      "create_signup_code"        => -> { post admin_signup_codes_path },
      "deactivate_signup_code"    => -> { patch deactivate_admin_signup_code_path(signup_code) },
      "unconfirmed_sessions"      => -> { get admin_unconfirmed_sessions_path },
      "confirm_sessions"          => -> { patch admin_confirm_sessions_path, params: { session_ids: [session_record.id] } },
      "unconfirmed_consultations" => -> { get admin_unconfirmed_consultations_path },
      "confirm_consultations"     => -> { patch admin_confirm_consultations_path, params: { consultation_ids: [consultation.id] } },
      "adjustments_new"           => -> { get admin_adjustments_new_path },
      "adjustments_preview"       => -> { post admin_adjustments_preview_path, params: { csv: csv_upload } },
      "adjustments_commit"        => -> { post admin_adjustments_commit_path, params: { payload: { rows: [] }.to_json, employee_id: create(:user).id } }
    }
  end

  def csv_upload
    Rack::Test::UploadedFile.new(StringIO.new("service_id,paid_used\n1,2\n"), "text/csv", original_filename: "adjustments.csv")
  end

  context "when signed out" do
    it "redirects every admin route to sign-in" do
      admin_requests.except("client_services").each do |name, request|
        request.call
        expect(response).to redirect_to(new_user_session_path), name
      end
    end

    it "answers 401 to the CSV export, which Devise does not redirect" do
      get "/admin/client_services"

      expect(response).to have_http_status(:unauthorized)
    end
  end

  %i[employee manager].each do |role|
    context "as #{role == :employee ? 'an employee' : 'a manager'}" do
      it "refuses every admin route with the existing redirect and message" do
        sign_in(role == :employee ? create(:user) : create(:user, role))

        admin_requests.each do |name, request|
          request.call
          expect(response).to redirect_to(authenticated_root_path), name
          expect(flash[:alert]).to eq("Not authorized"), name
        end
        expect(definition.reload.paid_sessions).to eq(4)
        expect(signup_code.reload).to be_active
      end
    end
  end

  %i[admin super_admin].each do |role|
    context "as #{role == :admin ? 'an admin' : 'the super admin'}" do
      before { sign_in create(:user, role) }

      it "reaches every admin route" do
        admin_requests.each do |name, request|
          request.call
          expect(response.status).to be < 400, name
          expect(flash[:alert]).not_to eq("Not authorized"), name
        end
      end

      it "updates a service definition" do
        patch update_admin_service_path(definition), params: { paid_sessions: 6, free_sessions: 1 }

        expect(definition.reload).to have_attributes(paid_sessions: 6, free_sessions: 1)
        expect(response).to redirect_to(admin_services_path)
      end

      it "manages signup codes" do
        expect { post admin_signup_codes_path }.to change(SignupCode, :count).by(1)

        patch deactivate_admin_signup_code_path(signup_code)
        expect(signup_code.reload).to be_deactivated
      end

      it "exports client services as CSV" do
        create(:fliip_service)
        get "/admin/client_services"

        expect(response.media_type).to eq("text/csv")
        expect(response.headers["Content-Disposition"]).to include("clients_services_")
      end

      it "enqueues the full Fliip sync instead of running it in the request" do
        expect { post import_clients_path }.to have_enqueued_job(FliipFullSyncJob)

        expect(response).to redirect_to(admin_dashboard_path)
        expect(flash[:notice]).to start_with("Synchronisation Fliip lancée en arrière-plan.")
      end

      it "previews then commits an adjustments CSV for the chosen employee" do
        service  = create(:fliip_service)
        employee = create(:user)

        post admin_adjustments_preview_path, params: { csv: csv_upload }
        expect(response).to have_http_status(:ok)

        payload = { rows: [{ "service_id" => service.id.to_s, "paid_used" => "2" }] }.to_json
        expect { post admin_adjustments_commit_path, params: { payload: payload, employee_id: employee.id } }
          .to change(ServiceUsageAdjustment, :count).by(1)
        expect(flash[:notice]).to eq("Adjustments imported: 1 created.")
      end

      it "asks for a file and an employee during the adjustments import" do
        post admin_adjustments_preview_path
        expect(flash[:alert]).to eq("Please choose a CSV file.")

        post admin_adjustments_commit_path, params: { payload: { rows: [] }.to_json }
        expect(flash[:alert]).to eq("Please select an employee.")
      end
    end
  end

  describe "who admins can see" do
    let!(:employee)    { create(:user) }
    let!(:super_admin) { create(:user, :super_admin) }

    # Lists and dropdowns are only visible in the markup.
    it "hides the super admin from an admin's dashboard and staff filters" do
      sign_in create(:user, :admin)

      get admin_dashboard_path
      expect(response.body).to include(user_path(employee))
      expect(response.body).not_to include(user_path(super_admin))

      get admin_unconfirmed_sessions_path
      expect(response.body).not_to include(%(value="#{super_admin.id}"))
      get admin_unconfirmed_consultations_path
      expect(response.body).not_to include(%(value="#{super_admin.id}"))
    end

    it "shows the super admin to themself on the dashboard, but not in employee filters" do
      sign_in super_admin

      get admin_dashboard_path
      expect(response.body).to include(user_path(super_admin))

      post admin_adjustments_preview_path, params: { csv: csv_upload }
      expect(response.body).to include(%(value="#{employee.id}"))
      expect(response.body).not_to include(%(value="#{super_admin.id}"))
    end
  end
end
