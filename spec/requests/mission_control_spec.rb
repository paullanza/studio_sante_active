require "rails_helper"

RSpec.describe "Mission Control", type: :request do
  it "sends signed-out visitors to sign-in" do
    get "/jobs"

    expect(response).to redirect_to(new_user_session_path)
  end

  it "shows the jobs dashboard to admins" do
    sign_in create(:user, :admin)
    get "/jobs"
    follow_redirect! while response.redirect?

    expect(response).to have_http_status(:ok)
  end
end
