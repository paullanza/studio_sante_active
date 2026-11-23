require "rails_helper"

RSpec.describe "Password help", type: :request do
  it "shows the help page to signed-out visitors" do
    get password_help_path

    expect(response).to have_http_status(:ok)
  end

  it "shows the help page to signed-in staff" do
    sign_in create(:user)
    get password_help_path

    expect(response).to have_http_status(:ok)
  end

  it "no longer routes Devise's email reset flow" do
    expect(Rails.application.routes.url_helpers).not_to respond_to(:new_user_password_path)
    expect { Rails.application.routes.recognize_path("/users/password/new") }
      .to raise_error(ActionController::RoutingError)
  end
end
