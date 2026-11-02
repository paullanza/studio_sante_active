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

    it "preloads the chosen client's services" do
      service = create(:fliip_service)
      sign_in create(:user)

      get new_seance_path(fliip_user_id: service.fliip_user_id, tab: "consultation")

      expect(response).to have_http_status(:ok)
    end

    it "offers admins every selectable employee but never the super admin" do
      employee    = create(:user)
      super_admin = create(:user, :super_admin)
      sign_in create(:user, :admin)

      get new_seance_path

      # The trainer options are only visible in the markup.
      expect(response.body).to include(%(<option value="#{employee.id}"))
      expect(response.body).not_to include(%(<option value="#{super_admin.id}"))
    end

    it "asks the super admin to pick an employee instead of booking for themself" do
      create(:user)
      sign_in create(:user, :super_admin)

      get new_seance_path

      # The required select and its prompt are only visible in the markup.
      expect(response.body).to include("Choisir un·e employé·e")
      expect(response.body).not_to include("Moi (")
    end
  end
end
