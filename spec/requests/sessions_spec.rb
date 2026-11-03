require "rails_helper"

RSpec.describe "Sessions", type: :request do
  let(:employee) { create(:user) }
  let(:service)  { create(:fliip_service) }

  def session_params(**overrides)
    {
      session: {
        fliip_user_id: service.fliip_user_id,
        fliip_service_id: service.id,
        date: Date.current.iso8601,
        time: "10:00",
        present: "1"
      }.merge(overrides)
    }
  end

  describe "POST /sessions" do
    it "creates a paid session for the signed-in employee" do
      sign_in employee

      expect { post sessions_path, params: session_params }.to change(Session, :count).by(1)

      session = Session.last
      expect(session.user).to eq(employee)
      expect(session.created_by).to eq(employee)
      expect(session).to be_paid
      expect(session).not_to be_confirmed
      expect(response).to redirect_to(new_seance_path)
    end

    it "records a half-hour session" do
      sign_in employee
      post sessions_path, params: session_params.merge(half_hour: "1")

      expect(Session.last.duration).to eq(0.5)
    end

    it "ignores user_id from employees" do
      other = create(:user)
      sign_in employee
      post sessions_path, params: session_params(user_id: other.id)

      expect(Session.last.user).to eq(employee)
    end

    it "lets admins book for another employee" do
      sign_in create(:user, :admin)
      post sessions_path, params: session_params(user_id: employee.id)

      expect(Session.last.user).to eq(employee)
    end

    it "re-renders the form with an error when the service is cancelled" do
      service.update!(purchase_status: "C")
      sign_in employee

      expect { post sessions_path, params: session_params }.not_to change(Session, :count)
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "re-renders the form with an error when the service is missing from Fliip" do
      service.update!(missing_from_fliip_at: 1.day.ago)
      sign_in employee

      expect { post sessions_path, params: session_params }.not_to change(Session, :count)
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "PATCH /sessions/:id and DELETE /sessions/:id" do
    let!(:session_record) { create(:session, fliip_service: service, user: employee, note: "original") }

    it "lets the owner update their unconfirmed session" do
      sign_in employee
      patch session_path(session_record),
            params: { session: { note: "updated", present: "1",
                                 date: Date.current.iso8601, time: "11:00" } }

      expect(response).to have_http_status(:ok)
      expect(session_record.reload.note).to eq("updated")
    end

    it "refuses updates from another employee" do
      sign_in create(:user)
      patch session_path(session_record), params: { session: { note: "hacked" } }

      expect(session_record.reload.note).to eq("original")
    end

    it "refuses deletes from another employee" do
      sign_in create(:user)

      expect { delete session_path(session_record) }.not_to change(Session, :count)
    end

    it "keeps a deactivated owner selected in the admin edit row" do
      employee.update!(active: false)
      sign_in create(:user, :admin)

      get edit_session_path(session_record)

      # The selected option is only visible in the markup.
      expect(response.body).to include(%(<option value="#{employee.id}" selected>))
    end

    it "lets admins delete confirmed sessions" do
      session_record.update_columns(confirmed: true)
      sign_in create(:user, :admin)

      expect { delete session_path(session_record) }.to change(Session, :count).by(-1)
    end
  end

  context "when signed out" do
    it "redirects every sessions route to sign-in" do
      session_record = create(:session)

      post sessions_path, params: session_params
      expect(response).to redirect_to(new_user_session_path)
      get edit_session_path(session_record)
      expect(response).to redirect_to(new_user_session_path)
      get row_session_path(session_record)
      expect(response).to redirect_to(new_user_session_path)
      get services_table_sessions_path(fliip_user_id: service.fliip_user_id)
      expect(response).to redirect_to(new_user_session_path)
    end
  end

  describe "choosing the trainer on create" do
    let(:super_admin) { create(:user, :super_admin) }

    it "ignores user_id from managers" do
      manager = create(:user, :manager)
      sign_in manager
      post sessions_path, params: session_params(user_id: employee.id)

      expect(Session.last.user).to eq(manager)
    end

    it "books for the admin when they leave the trainer blank" do
      admin = create(:user, :admin)
      sign_in admin
      post sessions_path, params: session_params

      expect(Session.last.user).to eq(admin)
      expect(Session.last.created_by).to eq(admin)
    end

    it "never books a session for the super admin" do
      sign_in create(:user, :admin)

      expect { post sessions_path, params: session_params(user_id: super_admin.id) }.not_to change(Session, :count)
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "requires the super admin to choose a trainer" do
      sign_in super_admin

      expect { post sessions_path, params: session_params }.not_to change(Session, :count)
      expect(response).to have_http_status(:unprocessable_content)
      expect(flash[:alert]).to include("Veuillez choisir un·e employé·e.")

      post sessions_path, params: session_params(user_id: employee.id)
      expect(Session.last.user).to eq(employee)
      expect(Session.last.created_by).to eq(super_admin)
    end
  end

  describe "editing by role" do
    let(:manager)  { create(:user, :manager) }
    let(:own)      { create(:session, fliip_service: service, user: employee, note: "original") }
    let(:confirmed) do
      create(:session, fliip_service: service, user: employee, occurred_at: 2.days.ago.change(min: 0)).tap do |s|
        s.update_columns(confirmed: true)
      end
    end
    let(:managers_own) { create(:session, fliip_service: service, user: manager, occurred_at: 3.days.ago.change(min: 0)) }

    def update_params(**overrides)
      { session: { note: "updated", present: "1", date: Date.current.iso8601, time: "15:00" }.merge(overrides) }
    end

    it "lets employees open their own unconfirmed session but not a confirmed one" do
      sign_in employee

      get edit_session_path(own)
      expect(response).to have_http_status(:ok)

      get edit_session_path(confirmed)
      expect(response).to redirect_to(admin_unconfirmed_sessions_path)
      expect(flash[:alert]).to eq("Non autorisé·e.")
    end

    it "answers 403 to JSON requests it refuses" do
      sign_in employee

      delete session_path(confirmed), headers: { "Accept" => "application/json" }

      expect(response).to have_http_status(:forbidden)
      expect(confirmed.reload).to be_present
    end

    it "ignores a trainer change from the owner" do
      sign_in employee
      patch session_path(own), params: update_params(user_id: create(:user).id)

      expect(own.reload.note).to eq("updated")
      expect(own.user).to eq(employee)
    end

    it "lets managers edit only their own sessions" do
      sign_in manager

      patch session_path(managers_own), params: update_params
      expect(managers_own.reload.note).to eq("updated")

      patch session_path(own), params: update_params(note: "manager", time: "16:00")
      expect(own.reload.note).to eq("original")
    end

    it "lets admins edit a confirmed session and reassign it" do
      other = create(:user)
      sign_in create(:user, :admin)

      patch session_path(confirmed), params: update_params(user_id: other.id)

      expect(response).to have_http_status(:ok)
      expect(confirmed.reload.user).to eq(other)
    end

    it "refuses to reassign a session to the super admin" do
      super_admin = create(:user, :super_admin)
      sign_in create(:user, :admin)

      patch session_path(own), params: update_params(user_id: super_admin.id)

      expect(response).to have_http_status(:unprocessable_content)
      expect(own.reload.user).to eq(employee)
    end

    it "lets the super admin edit and delete any session" do
      confirmed
      sign_in create(:user, :super_admin)

      patch session_path(managers_own), params: update_params(note: "super")
      expect(managers_own.reload.note).to eq("super")
      expect { delete session_path(confirmed) }.to change(Session, :count).by(-1)
    end

    it "leaves the super admin out of the admin's trainer list" do
      super_admin = create(:user, :super_admin)
      sign_in create(:user, :admin)

      get edit_session_path(own)

      # The option list is only visible in the markup.
      expect(response.body).to include(%(<option value="#{employee.id}"))
      expect(response.body).not_to include(%(<option value="#{super_admin.id}"))
    end
  end

  describe "routes open to every signed-in user" do
    let(:session_record) { create(:session, fliip_service: service) }

    %i[employee manager admin super_admin].each do |role|
      it "serve the row and booking helpers to a #{role}" do
        sign_in(role == :employee ? create(:user) : create(:user, role))

        get row_session_path(session_record)
        expect(response).to have_http_status(:ok)
        get services_table_sessions_path(fliip_user_id: service.fliip_user_id)
        expect(response).to have_http_status(:ok)
        get service_select_sessions_path(fliip_user_id: service.fliip_user_id)
        expect(response).to have_http_status(:ok)
        get "/sessions/preview_type", params: { fliip_service_id: service.id, present: "1" }
        expect(response.parsed_body).to eq("session_type" => "paid")
      end
    end

    it "previews an absence as free while free sessions remain" do
      sign_in employee
      get "/sessions/preview_type", params: { fliip_service_id: service.id, present: "0" }

      expect(response.parsed_body).to eq("session_type" => "free")
    end

    it "answers 404 when previewing an unknown service" do
      sign_in employee
      get "/sessions/preview_type", params: { fliip_service_id: 0 }

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /refresh_clients" do
    it "imports new clients from Fliip for any signed-in user" do
      allow(FliipApi::UserSync::NewUserImporter).to receive(:call).and_return("Sync complete")
      sign_in employee

      post refresh_clients_path

      expect(FliipApi::UserSync::NewUserImporter).to have_received(:call)
      expect(response).to redirect_to(new_seance_path)
      expect(flash[:notice]).to eq("Sync complete")
    end

    it "reports a failed import" do
      allow(FliipApi::UserSync::NewUserImporter).to receive(:call).and_raise("API indisponible")
      sign_in employee

      post refresh_clients_path

      expect(flash[:alert]).to eq("Impossible de rafraîchir les client·e·s : API indisponible")
    end
  end

  describe "PATCH /admin/confirm_sessions" do
    let!(:session_record) { create(:session, fliip_service: service) }

    it "lets admins and the super admin confirm sessions" do
      sign_in create(:user, :super_admin)
      patch admin_confirm_sessions_path, params: { session_ids: [session_record.id] }

      expect(session_record.reload).to be_confirmed
      expect(flash[:notice]).to eq("1 session confirmed.")
    end

    it "refuses employees" do
      sign_in employee
      patch admin_confirm_sessions_path, params: { session_ids: [session_record.id] }

      expect(session_record.reload).not_to be_confirmed
      expect(response).to redirect_to(authenticated_root_path)
    end
  end
end
