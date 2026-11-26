require "rails_helper"

RSpec.describe "Manager", type: :request do
  def manager_requests
    {
      "dashboard" => -> { get manager_dashboard_path }
    }
  end

  it "redirects to sign-in when signed out" do
    manager_requests.each do |name, request|
      request.call
      expect(response).to redirect_to(new_user_session_path), name
    end
  end

  it "lets managers see the dashboard" do
    sign_in create(:user, :manager)

    get manager_dashboard_path
    expect(response).to have_http_status(:ok)
  end

  %i[admin super_admin].each do |role|
    it "sends #{role == :admin ? 'an admin' : 'the super admin'} back to the admin dashboard" do
      sign_in create(:user, role)

      manager_requests.each do |name, request|
        request.call
        expect(response).to redirect_to(admin_dashboard_path), name
        expect(flash[:alert]).to eq("Admins must use the Admin dashboard"), name
      end
    end
  end

  it "sends employees to their own profile" do
    employee = create(:user)
    sign_in employee

    get manager_dashboard_path
    expect(response).to redirect_to(user_path(employee))
    expect(flash[:alert]).to eq("Not authorized")
  end

  it "lists staff without the super admin" do
    employee    = create(:user)
    super_admin = create(:user, :super_admin)
    sign_in create(:user, :manager)

    get manager_dashboard_path

    # The staff list is only visible in the markup.
    expect(response.body).to include(user_path(employee))
    expect(response.body).not_to include(user_path(super_admin))
  end
end
