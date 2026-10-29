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

  describe "admin pages" do
    it "are open to admins and super admins" do
      [admin, super_admin].each do |user|
        sign_in user
        get admin_dashboard_path
        expect(response).to have_http_status(:ok)
      end
    end

    it "are closed to managers and employees" do
      [manager, employee].each do |user|
        sign_in user
        get admin_dashboard_path
        expect(response).to have_http_status(:redirect)
        expect(response).not_to redirect_to(admin_dashboard_path)
      end
    end

    it "require sign-in" do
      get admin_dashboard_path
      expect(response).to redirect_to(new_user_session_path)
    end
  end

  describe "manager pages" do
    it "are open to managers" do
      sign_in manager
      get manager_dashboard_path
      expect(response).to have_http_status(:ok)
    end

    it "send admins back to the admin dashboard" do
      sign_in admin
      get manager_dashboard_path
      expect(response).to redirect_to(admin_dashboard_path)
    end

    it "are closed to employees" do
      sign_in employee
      get manager_dashboard_path
      expect(response).to redirect_to(user_path(employee))
    end
  end

  describe "confirming sessions" do
    let!(:session_record) { create(:session) }

    it "works for admins" do
      sign_in admin
      patch admin_confirm_sessions_path, params: { session_ids: [session_record.id] }

      expect(session_record.reload).to be_confirmed
    end

    it "is refused for managers" do
      sign_in manager
      patch admin_confirm_sessions_path, params: { session_ids: [session_record.id] }

      expect(session_record.reload).not_to be_confirmed
    end
  end

  describe "role changes" do
    it "let admins promote an employee to manager" do
      sign_in admin
      patch make_manager_user_path(employee)
      expect(employee.reload).to be_manager
    end

    it "let only super admins promote a manager to admin" do
      target = create(:user, :manager)

      sign_in admin
      patch make_admin_user_path(target)
      expect(target.reload).to be_manager

      sign_in super_admin
      patch make_admin_user_path(target)
      expect(target.reload).to be_admin
    end

    it "never change a super admin" do
      sign_in create(:user, :super_admin)
      patch make_manager_user_path(super_admin)
      expect(super_admin.reload).to be_super_admin
    end

    it "are refused for managers" do
      sign_in manager
      patch make_manager_user_path(employee)
      expect(employee.reload).to be_employee
    end
  end

  describe "deactivating users" do
    it "lets managers deactivate employees" do
      sign_in manager
      patch deactivate_user_path(employee)
      expect(employee.reload.active).to be false
    end

    it "does not let employees deactivate anyone" do
      other = create(:user)
      sign_in employee
      patch deactivate_user_path(other)
      expect(other.reload.active).to be true
    end
  end
end
