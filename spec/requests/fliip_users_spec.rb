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
      syncer = instance_double(FliipApi::UserSyncer)
      allow(FliipApi::Client).to receive(:new).and_return(instance_double(FliipApi::Client))
      allow(FliipApi::UserSyncer).to receive(:new).and_return(syncer)
      allow(syncer).to receive(:call_by_remote_id).and_return(FliipApi::UserSyncer::Result.new(user: client, user_change: :updated, services: {}, contracts: {}))
      sign_in(role == :employee ? create(:user) : create(:user, role))

      get fliip_users_path
      expect(response).to have_http_status(:ok)
      get fliip_user_path(client)
      expect(response).to have_http_status(:ok)
      get suggest_fliip_users_path(query: client.user_lastname)
      expect(response).to have_http_status(:ok)

      post refresh_fliip_user_path(client.remote_id)
      expect(syncer).to have_received(:call_by_remote_id).with(client.remote_id)
      expect(response).to redirect_to(fliip_user_path(client))
      expect(flash[:notice]).to eq("Client·e mis·e à jour depuis Fliip.")
    end
  end

  describe "POST /fliip_users/:remote_id/refresh" do
    let(:syncer) { instance_double(FliipApi::UserSyncer) }

    before do
      allow(FliipApi::Client).to receive(:new).and_return(instance_double(FliipApi::Client))
      allow(FliipApi::UserSyncer).to receive(:new).and_return(syncer)
      sign_in create(:user)
    end

    it "says when the client was already up to date" do
      allow(syncer).to receive(:call_by_remote_id).and_return(FliipApi::UserSyncer::Result.new(user: client, user_change: :unchanged, services: { created: 0, updated: 0, flagged: 0 }, contracts: { created: 0, updated: 0, flagged: 0 }))

      post refresh_fliip_user_path(client.remote_id)

      expect(flash[:notice]).to eq("Client·e déjà à jour.")
    end

    it "shows a French message when Fliip is unavailable, without a 500" do
      allow(syncer).to receive(:call_by_remote_id).and_raise(FliipApi::Unavailable, "timeout")

      post refresh_fliip_user_path(client.remote_id)

      expect(response).to redirect_to(fliip_users_path)
      expect(flash[:alert]).to eq("Fliip ne répond pas, réessayez plus tard.")
    end

    it "goes back to the client's page when Fliip no longer knows them" do
      allow(syncer).to receive(:call_by_remote_id).and_raise(FliipApi::NotFound, "400")

      post refresh_fliip_user_path(client.remote_id)

      expect(response).to redirect_to(fliip_user_path(client))
      expect(flash[:alert]).to eq("Client·e introuvable dans Fliip.")
    end

    it "goes to the client list for an id nobody knows" do
      allow(syncer).to receive(:call_by_remote_id).and_raise(FliipApi::NotFound, "400")

      post refresh_fliip_user_path(999_999)

      expect(response).to redirect_to(fliip_users_path)
    end

    it "rejects an id that isn't a number without calling Fliip" do
      allow(syncer).to receive(:call_by_remote_id)

      post "/fliip_users/abc/refresh"

      expect(syncer).not_to have_received(:call_by_remote_id)
      expect(flash[:alert]).to eq("Client·e introuvable dans Fliip.")
    end
  end

  it "shows the missing-from-Fliip flag on the client page" do
    client.update!(missing_from_fliip_at: 1.day.ago)
    sign_in create(:user)

    get fliip_user_path(client)
    expect(response.body).to include("Retiré de Fliip")
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
