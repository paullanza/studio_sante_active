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

  describe "GET /fliip_users/:id (client page)" do
    before do
      create(:fliip_contract, fliip_user: client)
      create(:consultation, fliip_user: client, fliip_service: service)
      create(:fliip_service, :without_definition, fliip_user: client)
      sign_in create(:user)
    end

    %w[services contracts consultations unknown].each do |tab|
      it "renders the #{tab} tab" do
        get fliip_user_path(client, tab: tab)

        expect(response).to have_http_status(:ok)
      end
    end

    it "marks a service Fliip no longer returns" do
      create(:fliip_service, :missing_from_fliip, fliip_user: client)

      get fliip_user_path(client)

      expect(response.body).to include("Retiré de Fliip", "historique seulement")
    end

    it "says when the client was last synced" do
      client.update_column(:synced_at, 2.hours.ago)

      get fliip_user_path(client)

      expect(response.body).to include("Synchronisé avec Fliip il y a environ 2 heures")
    end
  end

  it "filters the index by search" do
    sign_in create(:user)

    get fliip_users_path(query: client.user_lastname)

    expect(response).to have_http_status(:ok)
  end

  describe "GET /fliip_users (search)" do
    let!(:ysolde) do
      create(:fliip_user, user_firstname: "Ysolde", user_lastname: "Brisebois", user_phone1: "(514) 555-0142")
    end

    %i[employee manager admin super_admin].each do |role|
      context "as #{role}" do
        before { sign_in user_for(role) }

        it "lists every client before a search" do
          get fliip_users_path

          expect(response).to have_http_status(:ok)
          expect(response.body).to include("Ysolde Brisebois")
        end

        it "finds a client by name" do
          get fliip_users_path(query: "brisebois")

          expect(response).to have_http_status(:ok)
          expect(response.body).to include("Ysolde Brisebois")
        end

        it "finds a client by phone" do
          get fliip_users_path(query: "514-555-0142")

          expect(response.body).to include("Ysolde Brisebois")
        end
      end
    end

    it "says when nothing matches" do
      sign_in user_for(:employee)

      get fliip_users_path(query: "zzzz")

      expect(response.body).to include("Aucun client ne correspond")
    end

    it "pages through results, keeping the query" do
      create_list(:fliip_user, 50, user_lastname: "Brisebois")
      sign_in user_for(:employee)

      get fliip_users_path(query: "Brisebois")
      expect(response.body).to include(ERB::Util.html_escape(fliip_users_path(query: "Brisebois", page: 2)))

      get fliip_users_path(query: "Brisebois", page: 2)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(%(aria-current="page">2<))
    end

    it "lists clients by FliipUserID without a search" do
      create(:fliip_user, remote_id: 5, user_firstname: "Zoé")
      create(:fliip_user, remote_id: 3, user_firstname: "Aline")
      sign_in user_for(:employee)

      get fliip_users_path

      expect(response.body.index("Aline")).to be < response.body.index("Zoé")
    end

    it "answers a page past the last one without an error" do
      sign_in user_for(:employee)

      get fliip_users_path(page: 99)

      expect(response).to have_http_status(:ok)
    end

    it "pages through every client without a search" do
      create_list(:fliip_user, 50)
      sign_in user_for(:employee)

      get fliip_users_path(page: 2)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(%(aria-current="page">2<))
    end
  end

  it "suggests clients by phone, linking to Saisir with the client chosen" do
    client.update!(user_phone1: "514-555-0142")
    sign_in create(:user)

    get suggest_fliip_users_path(query: "555 0142")

    link = Nokogiri::HTML(response.body).at_css("a.suggestion")
    expect(link["href"]).to eq(new_seance_path(fliip_user_id: client.id))
  end

  it "serves the suggestion list on its own" do
    sign_in create(:user)

    get suggest_fliip_users_path(query: client.user_lastname, list_only: "1")

    expect(response).to have_http_status(:ok)
  end
end
