require "rails_helper"

RSpec.describe "Fliip users", type: :request do
  let(:service) { create(:fliip_service) }
  let(:client)  { service.fliip_user }

  it "redirects to sign-in when signed out" do
    get fliip_users_path

    expect(response).to redirect_to(new_user_session_path)
  end

  %i[employee manager admin super_admin].each do |role|
    it "lets a #{role} browse, open, search and refresh clients" do
      allow(FliipApi::UserSync::UserUpdater).to receive(:call).and_return("Sync complete")
      sign_in(role == :employee ? create(:user) : create(:user, role))

      get fliip_users_path
      expect(response).to have_http_status(:ok)
      get fliip_user_path(client)
      expect(response).to have_http_status(:ok)
      get suggest_fliip_users_path(query: client.user_lastname)
      expect(response).to have_http_status(:ok)

      post refresh_fliip_user_path(client.remote_id)
      expect(FliipApi::UserSync::UserUpdater).to have_received(:call).with(client.remote_id)
      expect(response).to redirect_to(fliip_user_path(client))
      expect(flash[:notice]).to eq("Sync complete")
    end
  end

  it "filters the index by search" do
    sign_in create(:user)

    get fliip_users_path(query: client.user_lastname)

    expect(response).to have_http_status(:ok)
  end

  it "serves the suggestion list on its own" do
    sign_in create(:user)

    get suggest_fliip_users_path(query: client.user_lastname, list_only: "1")

    expect(response).to have_http_status(:ok)
  end
end
