require "rails_helper"

RSpec.describe "Root", type: :request do
  it "shows the sign-in page when signed out" do
    get "/"

    expect(response).to have_http_status(:ok)
  end

  it "sends admins and the super admin to the admin dashboard" do
    [create(:user, :admin), create(:user, :super_admin)].each do |user|
      sign_in user
      get authenticated_root_path

      expect(response).to redirect_to(admin_dashboard_path)
    end
  end

  it "sends managers to the manager dashboard" do
    sign_in create(:user, :manager)
    get authenticated_root_path

    expect(response).to redirect_to(manager_dashboard_path)
  end

  it "sends employees to their profile" do
    employee = create(:user)
    sign_in employee
    get authenticated_root_path

    expect(response).to redirect_to(user_path(employee))
  end
end
