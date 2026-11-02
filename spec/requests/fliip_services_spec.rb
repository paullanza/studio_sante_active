require "rails_helper"

RSpec.describe "Fliip services", type: :request do
  let(:service) { create(:fliip_service) }

  it "redirects to sign-in when signed out" do
    get fliip_service_path(service)

    expect(response).to redirect_to(new_user_session_path)
  end

  %i[employee manager admin super_admin].each do |role|
    it "shows a service to a #{role}" do
      sign_in(role == :employee ? create(:user) : create(:user, role))

      get fliip_service_path(service)

      expect(response).to have_http_status(:ok)
    end
  end

  it "answers 404 for an unknown service" do
    sign_in create(:user)

    get fliip_service_path(0)

    expect(response).to have_http_status(:not_found)
  end
end
