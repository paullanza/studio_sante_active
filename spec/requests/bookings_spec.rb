require "rails_helper"

RSpec.describe "Bookings", type: :request do
  describe "GET /seances/new" do
    it "redirects to sign-in when signed out" do
      get new_seance_path

      expect(response).to redirect_to(new_user_session_path)
    end

    %i[employee manager admin super_admin].each do |role|
      it "opens the booking page for a #{role}" do
        sign_in(role == :employee ? create(:user) : create(:user, role))

        get new_seance_path

        expect(response).to have_http_status(:ok)
      end
    end

    context "with a client chosen" do
      let(:client) { create(:fliip_user) }

      before { sign_in create(:user) }

      def service_radio(service)
        Nokogiri::HTML(response.body).at_css("input[type=radio][name='session[fliip_service_id]'][value='#{service.id}']")
      end

      it "lists the client's services and checks the only bookable one" do
        bookable = create(:fliip_service, fliip_user: client, service_name: "Ent. privé, 12 mois")
        used_up = create(:fliip_service, fliip_user: client, service_name: "Ent. privé, 3 mois")
        create(:service_usage_adjustment, fliip_service: used_up, paid_used_delta: 10)

        get new_seance_path(fliip_user_id: client.id)

        expect(response).to have_http_status(:ok)
        expect(service_radio(bookable)["checked"]).to eq("checked")
        # A fully used service shows its reason and has no radio to choose it.
        expect(service_radio(used_up)).to be_nil
        expect(response.body).to include("Ent. privé, 3 mois", "Toutes les séances utilisées")
      end

      it "preselects the service from fliip_service_id" do
        create(:fliip_service, fliip_user: client)
        wanted = create(:fliip_service, fliip_user: client)

        get new_seance_path(fliip_user_id: client.id, fliip_service_id: wanted.id)

        expect(service_radio(wanted)["checked"]).to eq("checked")
      end

      it "checks nothing when several services can be booked" do
        services = create_list(:fliip_service, 2, fliip_user: client)

        get new_seance_path(fliip_user_id: client.id)

        expect(services.map { |s| service_radio(s)["checked"] }).to all(be_nil)
      end

      it "opens the consultation tab" do
        get new_seance_path(fliip_user_id: client.id, tab: "consultation")

        expect(response).to have_http_status(:ok)
        expect(Nokogiri::HTML(response.body).at_css("form[action='#{consultations_path}']")).to be_present
      end
    end

    it "offers admins every selectable employee but never the super admin" do
      employee    = create(:user)
      super_admin = create(:user, :super_admin)
      sign_in create(:user, :admin)

      get new_seance_path(fliip_user_id: create(:fliip_service).fliip_user_id)

      # The trainer options are only visible in the markup.
      expect(response.body).to include(%(<option value="#{employee.id}"))
      expect(response.body).not_to include(%(<option value="#{super_admin.id}"))
    end

    it "asks the super admin to pick an employee instead of booking for themself" do
      create(:user)
      sign_in create(:user, :super_admin)

      get new_seance_path(fliip_user_id: create(:fliip_service).fliip_user_id)

      # The required select and its prompt are only visible in the markup.
      expect(response.body).to include("Choisir un·e employé·e")
      expect(response.body).not_to include("Moi (")
    end
  end
end
