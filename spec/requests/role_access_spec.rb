require "rails_helper"

RSpec.describe "Role-based access", type: :request do
  let(:employee)    { create(:user) }
  let(:manager)     { create(:user, :manager) }
  let(:admin)       { create(:user, :admin) }
  let(:super_admin) { create(:user, :super_admin) }

  describe "after sign-in" do
    def sign_in_with_form(user)
      post user_session_path, params: { user: { email: user.email, password: "password123" } }
    end

    it "sends admins to the admin dashboard" do
      sign_in_with_form(admin)
      expect(response).to redirect_to(admin_dashboard_path)
    end

    it "sends managers to the manager dashboard" do
      sign_in_with_form(manager)
      expect(response).to redirect_to(manager_dashboard_path)
    end

    it "sends employees to their profile" do
      sign_in_with_form(employee)
      expect(response).to redirect_to(user_path(employee))
    end

    it "refuses deactivated users" do
      user = create(:user, :inactive)
      sign_in_with_form(user)
      expect(response).not_to redirect_to(user_path(user))

      get user_path(user)
      expect(response).to redirect_to(new_user_session_path)
    end
  end

  describe "root redirect" do
    it "routes each role to its home page" do
      { admin => admin_dashboard_path, manager => manager_dashboard_path }.each do |user, path|
        sign_in user
        get authenticated_root_path
        expect(response).to redirect_to(path)
      end

      sign_in employee
      get authenticated_root_path
      expect(response).to redirect_to(user_path(employee))
    end
  end

  describe "a user deactivated mid-session" do
    it "is signed out on the next request" do
      sign_in employee
      employee.update!(active: false)

      get user_path(employee)
      expect(response).to redirect_to(new_user_session_path)
    end
  end


  # One row per route in the Pundit Authorization Spec's permission matrix:
  # the request to make, and the roles allowed to make it. Every role not
  # listed must be refused. Detailed rules live in each controller's spec.
  describe "route permission matrix" do
    ROLES = %i[employee manager admin super_admin].freeze
    ALL = ROLES
    MANAGEMENT = %i[manager admin super_admin].freeze
    ADMINS = %i[admin super_admin].freeze

    # Alerts the app uses when it refuses a request.
    REFUSALS = [
      "Non autorisé·e.", "Not authorized", "Not authorized.", "Admins must use the Admin dashboard",
      "Not authorized to activate this user.", "Not authorized to deactivate this user."
    ].freeze

    let(:actors) { ROLES.index_with { |role| role == :employee ? employee : create(:user, role) } }
    let(:service) { create(:fliip_service, purchase_date: 1.day.ago) }
    let(:other_employee) { create(:user) }

    def refused?
      response.status == 403 || REFUSALS.include?(flash[:alert])
    end

    # Each row's request runs against records owned by someone else, so
    # "allowed" means the role itself is allowed, not the record's owner.
    def rows
      session_record = create(:session, fliip_service: service, user: other_employee)
      consultation   = create(:consultation, user: other_employee)
      associated     = create(:consultation, user: other_employee, fliip_user: service.fliip_user,
                                             fliip_service: create(:fliip_service, fliip_user: service.fliip_user))
      adjustment     = create(:service_usage_adjustment, fliip_service: service, user: other_employee)
      manager_target = create(:user, :manager)
      session_edit   = { session: { note: "x", present: "1", date: Date.current.iso8601, time: "15:00" } }
      consult_edit   = { consultation: { first_name: "A", last_name: "B", phone_number: "1", date: Date.current.iso8601, time: "09:00" } }

      {
        "S1 GET /seances/new"                => [ALL, -> { get new_seance_path }],
        "S3 GET /sessions/:id/edit (other)"  => [ADMINS, -> { get edit_session_path(session_record) }],
        "S3 PATCH /sessions/:id (other)"     => [ADMINS, -> { patch session_path(session_record), params: session_edit }],
        "S4 GET /sessions/:id/row"           => [ALL, -> { get row_session_path(session_record) }],
        "S5 GET /sessions/services_table"    => [ALL, -> { get services_table_sessions_path(fliip_user_id: service.fliip_user_id) }],
        "S5 GET /sessions/preview_type"      => [ALL, -> { get "/sessions/preview_type", params: { fliip_service_id: service.id } }],
        "S6 POST /refresh_clients"           => [ALL, -> { post refresh_clients_path }],
        "C3 GET /consultations/:id/edit (other)" => [ADMINS, -> { get edit_consultation_path(consultation) }],
        "C3 PATCH /consultations/:id (other)"    => [ADMINS, -> { patch consultation_path(consultation), params: consult_edit }],
        "C3b GET /consultations/:id/association" => [MANAGEMENT, -> { get association_consultation_path(consultation) }],
        "C4 GET /consultations/:id/row"          => [ALL, -> { get row_consultation_path(consultation) }],
        "C5 PATCH /consultations/:id/disassociate" => [ADMINS, -> { patch disassociate_consultation_path(associated) }],
        "C6 GET /consultations/associations"     => [MANAGEMENT, -> { get associations_consultations_path }],
        "U1 GET /users/:id (employee)"       => [MANAGEMENT, -> { get user_path(other_employee) }],
        "U2 GET /users/:id/edit (employee)"  => [ADMINS, -> { get edit_user_path(other_employee) }],
        "U3 PATCH make_employee (manager)"   => [ADMINS, -> { patch make_employee_user_path(manager_target) }],
        "U4 PATCH make_manager (employee)"   => [ADMINS, -> { patch make_manager_user_path(create(:user)) }],
        "U5 PATCH make_admin (manager)"      => [%i[super_admin], -> { patch make_admin_user_path(create(:user, :manager)) }],
        "U6 PATCH deactivate (employee)"     => [MANAGEMENT, -> { patch deactivate_user_path(create(:user)) }],
        "U6 PATCH deactivate (manager)"      => [ADMINS, -> { patch deactivate_user_path(create(:user, :manager)) }],
        "U6 PATCH deactivate (admin)"        => [%i[super_admin], -> { patch deactivate_user_path(create(:user, :admin)) }],
        "A1 GET admin/dashboard"             => [ADMINS, -> { get admin_dashboard_path }],
        "A9 GET admin/unconfirmed_sessions"  => [ADMINS, -> { get admin_unconfirmed_sessions_path }],
        "A10 PATCH admin/confirm_sessions"   => [ADMINS, -> { patch admin_confirm_sessions_path, params: { session_ids: [session_record.id] } }],
        "A13 GET admin/adjustments/new"      => [ADMINS, -> { get admin_adjustments_new_path }],
        "J1 GET /jobs (Mission Control)"     => [ADMINS, -> { get "/jobs" }],
        "M1 GET manager/dashboard"           => [%i[manager], -> { get manager_dashboard_path }],
        "M4 POST manager/signup_codes"       => [%i[manager], -> { post manager_signup_codes_path }],
        "X1 GET /fliip_users"                => [ALL, -> { get fliip_users_path }],
        "X1 GET /fliip_users/:id"            => [ALL, -> { get fliip_user_path(service.fliip_user) }],
        "X2 POST fliip_users/:remote_id/refresh" => [ALL, -> { post refresh_fliip_user_path(service.fliip_user.remote_id) }],
        "X3 GET /fliip_services/:id"         => [ALL, -> { get fliip_service_path(service) }],
        "X4 POST service_usage_adjustments"  => [ADMINS, -> { post fliip_service_service_usage_adjustments_path(service), params: { service_usage_adjustment: { bonus_sessions: 1, user_id: other_employee.id } } }],
        "X5 GET service_usage_adjustments/:id/edit" => [ADMINS, -> { get edit_fliip_service_service_usage_adjustment_path(service, adjustment) }]
      }
    end

    before do
      syncer = instance_double(FliipApi::UserSyncer)
      counts = { created: 0, updated: 0, unchanged: 0, flagged: 0 }
      allow(FliipApi::Client).to receive(:new).and_return(instance_double(FliipApi::Client))
      allow(FliipApi::UserSyncer).to receive(:new).and_return(syncer)
      allow(syncer).to receive(:call_by_remote_id) { |id| FliipApi::UserSyncer::Result.new(user: FliipUser.find_by!(remote_id: id), user_change: :unchanged, services: counts, contracts: counts) }
      allow(FliipApi::NewClients).to receive(:new).and_return(instance_double(FliipApi::NewClients, call: FliipApi::BatchSync::Summary.empty))
    end

    ROLES.each do |role|
      it "allows and refuses each route for #{role == :employee ? 'an employee' : "a #{role}"}" do
        actor = actors.fetch(role)

        rows.each do |label, (allowed_roles, request)|
          # A fresh session per row, so a refusal's flash can't leak into the next one.
          reset!
          sign_in actor
          request.call
          expect(refused?).to eq(!allowed_roles.include?(role)),
                              "#{label}: expected #{allowed_roles.include?(role) ? 'allowed' : 'refused'} (#{response.status} #{flash[:alert].inspect})"
        end
      end
    end

    it "keeps the super admin out of every role's reach but their own" do
      super_admin = create(:user, :super_admin)

      %i[employee manager admin].each do |role|
        reset!
        sign_in actors.fetch(role)
        get user_path(super_admin)
        expect(refused?).to be(true), role.to_s
        patch deactivate_user_path(super_admin)
        expect(super_admin.reload).to be_active
      end
    end
  end
end
