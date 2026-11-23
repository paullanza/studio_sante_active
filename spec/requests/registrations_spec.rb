require "rails_helper"

# Devise sign-up with a signup code. Editing and deleting an account through
# Devise are not routed.
RSpec.describe "Sign up", type: :request do
  let(:code) { create(:signup_code) }

  def user_params(**overrides)
    {
      signup_code_token: code.code,
      first_name: "Ysolde",
      last_name: "Brisebois",
      phone: "514-555-0199",
      birthday: "1990-04-12",
      address: "123 rue Saint-Denis, Montréal, QC",
      email: "ysolde@example.com",
      password: "password123",
      password_confirmation: "password123"
    }.merge(overrides)
  end

  def sign_up(**overrides)
    post user_registration_path, params: { user: user_params(**overrides) }
  end

  it "shows the sign-up page on the new layout" do
    get new_user_registration_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("/assets/studio-")
  end

  context "with a usable code and valid fields" do
    it "creates an employee, consumes the code and signs them in" do
      expect { sign_up }.to change(User, :count).by(1)

      user = User.find_by!(email: "ysolde@example.com")
      expect(user).to be_employee
      expect(code.reload).to be_used
      expect(code.used_by).to eq(user)
      expect(response).to redirect_to(user_path(user))

      follow_redirect!
      expect(response).to have_http_status(:ok)
    end
  end

  {
    "blank" => -> { "" },
    "unknown" => -> { "ZZZZZZZZ" },
    "deactivated" => -> { create(:signup_code, :deactivated).code },
    "used" => -> { create(:signup_code).tap { |c| c.update_columns(status: SignupCode.statuses[:used]) }.code },
    "expired" => -> { create(:signup_code, :expired).code }
  }.each do |state, token|
    context "with a #{state} code" do
      it "re-renders the form and leaves the code alone" do
        token_value = instance_exec(&token)
        signup_code = SignupCode.find_by(code: token_value)

        expect { sign_up(signup_code_token: token_value) }.not_to change(User, :count)
        expect(response).to have_http_status(:unprocessable_content)
        expect(signup_code&.reload&.status).to eq(signup_code&.status)
      end
    end
  end

  context "with an expired code" do
    it "says the code has expired" do
      sign_up(signup_code_token: create(:signup_code, :expired).code)

      expect(response.body).to include("a expiré")
    end
  end

  context "with a missing first name" do
    it "re-renders the form with the error" do
      expect { sign_up(first_name: "") }.not_to change(User, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("ne peut pas être vide")
      expect(code.reload).to be_active
    end
  end

  context "with the Devise account routes" do
    it "does not route deleting an account" do
      expect { Rails.application.routes.recognize_path("/users", method: :delete) }
        .to raise_error(ActionController::RoutingError)
    end

    # GET /users/edit and /users/cancel fall through to users#show, whose
    # User.find answers 404; they never reach Devise.
    %w[/users/edit /users/cancel].each do |path|
      it "does not send GET #{path} to Devise" do
        expect(Rails.application.routes.recognize_path(path, method: :get))
          .not_to include(controller: "devise/registrations")
      end
    end

    it "does not route updating an account through Devise" do
      expect { Rails.application.routes.recognize_path("/users", method: :patch) }
        .to raise_error(ActionController::RoutingError)
    end
  end
end
