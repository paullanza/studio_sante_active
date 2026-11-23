require "rails_helper"

RSpec.describe "Mon profil", type: :request do
  let(:user) { create(:user, phone: "514-555-0000") }

  def change_password(current:, password: "nouveau-mdp-123", confirmation: password)
    patch password_profile_path, params: {
      user: { current_password: current, password: password, password_confirmation: confirmation }
    }
  end

  %i[employee manager admin super_admin].each do |role|
    context "when signed in as #{role}" do
      it "shows the page" do
        sign_in user_for(role)
        get profile_path
        expect(response).to have_http_status(:ok)
      end
    end
  end

  context "when signed out" do
    it "redirects to sign in" do
      get profile_path
      expect(response).to redirect_to(new_user_session_path)
    end
  end

  context "when saving valid details" do
    before { sign_in user }

    it "saves them and redirects with a notice" do
      patch profile_path, params: { user: { phone: "438-555-1234", email: "nouveau@example.com" } }

      expect(response).to redirect_to(profile_path)
      expect(flash[:notice]).to eq("Profil mis à jour.")
      expect(user.reload).to have_attributes(phone: "438-555-1234", email: "nouveau@example.com")
    end
  end

  context "when the first name is blank" do
    before { sign_in user }

    it "refuses with 422 and saves nothing" do
      patch profile_path, params: { user: { first_name: "", phone: "438-555-1234" } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(user.reload.phone).to eq("514-555-0000")
    end
  end

  context "when role or active is sent" do
    before { sign_in user }

    it "leaves them unchanged" do
      patch profile_path, params: { user: { role: "admin", active: "0", phone: "438-555-1234" } }

      expect(user.reload).to have_attributes(role: "employee", active: true, phone: "438-555-1234")
    end
  end

  context "when changing the password with the right current password" do
    before { sign_in user }

    it "changes it and keeps the person signed in" do
      change_password(current: "password123")

      expect(response).to redirect_to(profile_path)
      expect(flash[:notice]).to eq("Mot de passe modifié.")
      expect(user.reload.valid_password?("nouveau-mdp-123")).to be(true)

      get profile_path
      expect(response).to have_http_status(:ok)
    end
  end

  context "when the current password is wrong" do
    before { sign_in user }

    it "refuses with 422 and keeps the old password" do
      change_password(current: "mauvais")

      expect(response).to have_http_status(:unprocessable_content)
      expect(user.reload.valid_password?("password123")).to be(true)
    end
  end

  context "when the confirmation does not match" do
    before { sign_in user }

    it "refuses with 422 and keeps the old password" do
      change_password(current: "password123", confirmation: "autre-chose-123")

      expect(response).to have_http_status(:unprocessable_content)
      expect(user.reload.valid_password?("password123")).to be(true)
    end
  end

  context "when the new password is blank" do
    before { sign_in user }

    it "refuses with 422 instead of reporting a change" do
      change_password(current: "password123", password: "")

      expect(response).to have_http_status(:unprocessable_content)
      expect(user.reload.valid_password?("password123")).to be(true)
    end
  end
end
