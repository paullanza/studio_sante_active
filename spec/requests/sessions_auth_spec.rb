require "rails_helper"

# Devise sign-in and sign-out (staff login), not the Session (séance) model.
RSpec.describe "Sign in and sign out", type: :request do
  def sign_in_with_form(email:, password: "password123")
    post user_session_path, params: { user: { email: email, password: password } }
  end

  it "shows the sign-in page on the new layout" do
    get new_user_session_path

    expect(response).to have_http_status(:ok)
    # The layout's stylesheet is the only sign of which layout rendered.
    expect(response.body).to include("/assets/studio-")
  end

  it "puts « Mot de passe oublié? » after « Se connecter », so Tab reaches it last" do
    get new_user_session_path

    form = Nokogiri::HTML(response.body).at_css("form.auth-split__form")
    order = form.css("button[type=submit], a[href='#{password_help_path}']").map(&:name)
    expect(order).to eq(%w[button a])
  end

  it "sends admins to the admin dashboard" do
    sign_in_with_form(email: create(:user, :admin).email)

    expect(response).to redirect_to(admin_dashboard_path)
  end

  it "sends the super admin to the admin dashboard" do
    sign_in_with_form(email: create(:user, :super_admin).email)

    expect(response).to redirect_to(admin_dashboard_path)
  end

  it "sends managers to the manager dashboard" do
    sign_in_with_form(email: create(:user, :manager).email)

    expect(response).to redirect_to(manager_dashboard_path)
  end

  it "sends employees to their profile" do
    employee = create(:user)
    sign_in_with_form(email: employee.email)

    expect(response).to redirect_to(user_path(employee))
  end

  it "refuses a wrong password with the French message" do
    sign_in_with_form(email: create(:user).email, password: "wrong-password")

    expect(response).to have_http_status(:unprocessable_content)
    expect(flash[:alert]).to eq("Courriel ou mot de passe invalide.")
  end

  it "refuses an unknown email with the same message" do
    sign_in_with_form(email: "nobody@example.test")

    expect(flash[:alert]).to eq("Courriel ou mot de passe invalide.")
  end

  it "refuses a deactivated user with the French message" do
    sign_in_with_form(email: create(:user, :inactive).email)

    expect(response).to redirect_to(new_user_session_path)
    expect(flash[:alert]).to eq(I18n.t("devise.failure.inactive"))
    expect(I18n.t("devise.failure.inactive")).to start_with("Votre compte est désactivé.")
  end

  it "signs out a user deactivated mid-session on their next request" do
    employee = create(:user)
    sign_in employee
    employee.update!(active: false)

    get user_path(employee)

    expect(response).to redirect_to(new_user_session_path)
    expect(flash[:alert]).to eq(I18n.t("devise.failure.inactive"))
    get user_path(employee)
    expect(response).to redirect_to(new_user_session_path)
  end

  it "signs out" do
    employee = create(:user)
    sign_in employee

    delete destroy_user_session_path
    expect(flash[:notice]).to eq("Déconnexion réussie.")

    get user_path(employee)
    expect(response).to redirect_to(new_user_session_path)
  end
end
