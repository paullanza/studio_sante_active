require "rails_helper"

RSpec.describe "Admin", type: :request do
  let(:signup_code)  { create(:signup_code) }
  let(:session_record) { create(:session) }
  let(:consultation) { create(:consultation) }

  # Every admin route with a request that should succeed for admins.
  def admin_requests
    {
      "dashboard"                 => -> { get admin_dashboard_path },
      "import_clients"            => -> { post import_clients_path },
      "create_signup_code"        => -> { post admin_signup_codes_path },
      "deactivate_signup_code"    => -> { patch deactivate_admin_signup_code_path(signup_code) },
      "unconfirmed_consultations" => -> { get admin_unconfirmed_consultations_path },
      "confirm_consultations"     => -> { patch admin_confirm_consultations_path, params: { consultation_ids: [consultation.id] } }
    }
  end

  context "when signed out" do
    it "redirects every admin route to sign-in" do
      admin_requests.each do |name, request|
        request.call
        expect(response).to redirect_to(new_user_session_path), name
      end
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

      it "manages signup codes" do
        expect { post admin_signup_codes_path }.to change(SignupCode, :count).by(1)

        patch deactivate_admin_signup_code_path(signup_code)
        expect(signup_code.reload).to be_deactivated
      end

      it "enqueues the full Fliip sync instead of running it in the request" do
        expect { post import_clients_path }.to have_enqueued_job(FliipFullSyncJob)

        expect(response).to redirect_to(admin_dashboard_path)
        expect(flash[:notice]).to start_with("Synchronisation Fliip lancée en arrière-plan.")
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

      get session_confirmations_path
      expect(response.body).not_to include(%(value="#{super_admin.id}"))
      get admin_unconfirmed_consultations_path
      expect(response.body).not_to include(%(value="#{super_admin.id}"))
    end

    it "shows the super admin to themself on the dashboard, but not in employee filters" do
      sign_in super_admin

      get admin_dashboard_path
      expect(response.body).to include(user_path(super_admin))

      get session_confirmations_path
      expect(response.body).to include(%(value="#{employee.id}"))
      expect(response.body).not_to include(%(value="#{super_admin.id}"))
    end
  end
end
