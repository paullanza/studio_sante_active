require "rails_helper"

RSpec.describe "Users", type: :request do
  let!(:employee)    { create(:user) }
  let!(:colleague)   { create(:user) }
  let!(:manager)     { create(:user, :manager) }
  let!(:other_manager) { create(:user, :manager) }
  let!(:admin)       { create(:user, :admin) }
  let!(:other_admin) { create(:user, :admin) }
  let!(:super_admin) { create(:user, :super_admin) }

  def everyone
    { employee:, colleague:, manager:, other_manager:, admin:, other_admin:, super_admin: }
  end

  def profile_params(**overrides)
    { user: { first_name: "Nouveau", email: "nouveau-#{SecureRandom.hex(3)}@example.com",
              password: "changed123", role: "super_admin", active: "0" }.merge(overrides) }
  end

  context "when signed out" do
    it "redirects to sign-in" do
      get user_path(employee)
      expect(response).to redirect_to(new_user_session_path)
      patch deactivate_user_path(employee)
      expect(response).to redirect_to(new_user_session_path)
    end
  end

  describe "GET /users/:id" do
    {
      employee: %i[employee],
      manager: %i[employee colleague manager other_manager admin other_admin],
      admin: %i[employee colleague manager other_manager admin other_admin],
      super_admin: %i[employee colleague manager other_manager admin other_admin super_admin]
    }.each do |viewer, visible|
      it "shows a #{viewer} only the profiles they may see" do
        sign_in everyone[viewer]

        everyone.each do |name, user|
          get user_path(user)
          expect(response.status == 200).to eq(visible.include?(name)), "#{viewer} viewing #{name}"
        end
      end
    end

    it "sends a refused viewer back with an alert" do
      sign_in employee
      get user_path(colleague)

      expect(response).to redirect_to(authenticated_root_path)
      expect(flash[:alert]).to eq("Non autorisé·e.")
    end
  end

  describe "editing profiles" do
    {
      employee: %i[employee],
      manager: %i[manager],
      admin: %i[employee colleague manager other_manager admin other_admin],
      super_admin: %i[employee colleague manager other_manager admin other_admin super_admin]
    }.each do |editor, editable|
      it "lets a #{editor} edit only the profiles they may" do
        sign_in everyone[editor]

        everyone.each do |name, user|
          get edit_user_path(user)
          expect(response.status == 200).to eq(editable.include?(name)), "#{editor} editing #{name}"

          patch user_path(user), params: profile_params
          expect(user.reload.first_name == "Nouveau").to eq(editable.include?(name)), "#{editor} updating #{name}"
          user.update_columns(first_name: "Avant")
        end
      end
    end

    it "changes the email only on your own profile" do
      sign_in admin

      patch user_path(employee), params: profile_params(email: "autre@example.com")
      expect(employee.reload.email).not_to eq("autre@example.com")

      patch user_path(admin), params: profile_params(email: "moi@example.com")
      expect(admin.reload.email).to eq("moi@example.com")
    end

    it "never changes the password, role or active flag" do
      sign_in super_admin

      patch user_path(employee), params: profile_params

      employee.reload
      expect(employee.valid_password?("changed123")).to be false
      expect(employee).to be_employee
      expect(employee).to be_active
    end

    it "keeps the old alert when a visible profile cannot be edited" do
      sign_in manager
      get edit_user_path(employee)

      expect(response).to redirect_to(user_path(employee))
      expect(flash[:alert]).to eq("Not authorized.")
    end

    it "re-renders the profile with errors when a field is invalid" do
      sign_in employee
      patch user_path(employee), params: { user: { first_name: "" } }

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "role changes" do
    it "lets admins demote a manager and promote an employee" do
      sign_in admin

      patch make_employee_user_path(manager)
      expect(manager.reload).to be_employee
      patch make_manager_user_path(employee)
      expect(employee.reload).to be_manager
    end

    it "stops admins from changing any admin, themself included, or making admins" do
      sign_in admin

      patch make_manager_user_path(other_admin)
      patch make_manager_user_path(admin)
      patch make_admin_user_path(manager)

      expect(other_admin.reload).to be_admin
      expect(admin.reload).to be_admin
      expect(manager.reload).to be_manager
    end

    it "lets the super admin demote an admin and promote a manager to admin" do
      sign_in super_admin

      patch make_manager_user_path(admin)
      expect(admin.reload).to be_manager
      patch make_admin_user_path(other_manager)
      expect(other_admin.reload).to be_admin
      expect(other_manager.reload).to be_admin
    end

    it "keeps each target rule and its message" do
      sign_in super_admin

      patch make_admin_user_path(employee)
      expect(flash[:alert]).to eq("Only managers can be promoted to admin.")
      patch make_employee_user_path(employee)
      expect(flash[:alert]).to eq("Only managers can be demoted to employee.")
      patch make_manager_user_path(manager)
      expect(flash[:alert]).to eq("This change isn’t allowed.")
    end

    it "never changes the super admin" do
      sign_in super_admin

      patch make_manager_user_path(super_admin)

      expect(super_admin.reload).to be_super_admin
      expect(flash[:alert]).to eq("You can't change a Super Admin.")
    end

    it "is refused to managers and employees" do
      [manager, employee].each do |user|
        sign_in user
        patch make_manager_user_path(colleague)
        expect(colleague.reload).to be_employee
      end
    end
  end

  describe "activation" do
    {
      employee: [],
      manager: %i[employee colleague],
      admin: %i[employee colleague manager other_manager],
      super_admin: %i[employee colleague manager other_manager admin other_admin]
    }.each do |actor, allowed|
      it "lets a #{actor} deactivate and reactivate only the users they may" do
        sign_in everyone[actor]

        everyone.each do |name, user|
          patch deactivate_user_path(user)
          expect(user.reload.active).to eq(!allowed.include?(name)), "#{actor} deactivating #{name}"

          user.update_columns(active: false)
          patch activate_user_path(user)
          expect(user.reload.active).to eq(allowed.include?(name)), "#{actor} activating #{name}"
          user.update_columns(active: true)
        end
      end
    end

    it "keeps the old alerts" do
      sign_in manager

      patch deactivate_user_path(other_manager)
      expect(flash[:alert]).to eq("Not authorized to deactivate this user.")
      patch activate_user_path(other_manager)
      expect(flash[:alert]).to eq("Not authorized to activate this user.")
    end
  end
end
