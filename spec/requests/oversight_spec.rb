require "rails_helper"

RSpec.describe "Oversight", type: :request do
  describe "GET /echeances" do
    it "redirects to sign-in when signed out" do
      get echeances_path

      expect(response).to redirect_to(new_user_session_path)
    end

    %i[manager admin super_admin].each do |role|
      it "shows both tabs to a#{'n' if role == :admin} #{role}" do
        sign_in user_for(role)

        get echeances_path
        expect(response).to have_http_status(:ok)
        get echeances_path(tab: "recents")
        expect(response).to have_http_status(:ok)
      end
    end

    it "refuses an employee" do
      sign_in create(:user)

      get echeances_path

      expect(response).to redirect_to(authenticated_root_path)
      expect(flash[:alert]).to eq("Non autorisé·e.")
    end

    context "with services around today" do
      before { travel_to Time.zone.local(2026, 11, 24, 10) }

      let!(:ending_soon) { create(:fliip_service, service_name: "Finit dans 10 jours", expire_date: Date.new(2026, 12, 4)) }
      let!(:ending_later) { create(:fliip_service, service_name: "Finit dans 3 jours", expire_date: Date.new(2026, 11, 27)) }
      let!(:ending_inactive) { create(:fliip_service, service_name: "Inactif bientôt", purchase_status: "I", expire_date: Date.new(2026, 12, 1)) }
      let!(:ended_recently) { create(:fliip_service, service_name: "Fini il y a 5 jours", expire_date: Date.new(2026, 11, 19)) }
      let!(:ended_long_ago) do
        create(:fliip_service, service_name: "Fini il y a 40 jours", start_date: Date.new(2026, 6, 1), expire_date: Date.new(2026, 10, 15))
      end

      before { sign_in create(:user, :manager) }

      it "lists active services ending in the next 30 days, soonest first, with the client's name" do
        get echeances_path

        expect(response.body).to include("Se terminent bientôt (2)", "Terminés récemment (1)", ending_soon.fliip_user.full_name)
        expect(response.body).not_to include("Inactif bientôt", "Fini il y a 5 jours", "Fini il y a 40 jours")
        expect(response.body.index("Finit dans 3 jours")).to be < response.body.index("Finit dans 10 jours")
      end

      it "lists services that ended in the last 30 days on the second tab" do
        get echeances_path(tab: "recents")

        expect(response.body).to include("Fini il y a 5 jours")
        expect(response.body).not_to include("Finit dans 10 jours", "Fini il y a 40 jours")
      end

      it "names the staff who logged séances or adjustments on each service" do
        trainer = create(:user, first_name: "Ysolde", last_name: "Brisebois")
        adjuster = create(:user, first_name: "Aline", last_name: "Côté")
        create(:session, fliip_service: ending_soon, user: trainer, occurred_at: 2.days.ago)
        create(:session, fliip_service: ending_soon, user: trainer, occurred_at: 1.day.ago)
        create(:service_usage_adjustment, fliip_service: ending_soon, user: adjuster)

        get echeances_path

        expect(response.body).to include("Entraîneur·e·s : Aline Côté, Ysolde Brisebois")
        expect(response.body).to include("Entraîneur·e·s : —")
      end
    end
  end

  describe "GET /seances-recentes" do
    it "redirects to sign-in when signed out" do
      get recent_sessions_path

      expect(response).to redirect_to(new_user_session_path)
    end

    %i[manager admin super_admin].each do |role|
      it "shows the page to a#{'n' if role == :admin} #{role}" do
        sign_in user_for(role)

        get recent_sessions_path

        expect(response).to have_http_status(:ok)
      end
    end

    it "refuses an employee" do
      sign_in create(:user)

      get recent_sessions_path

      expect(response).to redirect_to(authenticated_root_path)
      expect(flash[:alert]).to eq("Non autorisé·e.")
    end

    context "with séances" do
      before { travel_to Time.zone.local(2026, 11, 24, 10) }

      let(:trainer) { create(:user, first_name: "Ysolde", last_name: "Brisebois") }
      let(:other_trainer) { create(:user, first_name: "Aline", last_name: "Côté") }
      let(:service) { create(:fliip_service, service_name: "Entraînement duo") }
      let!(:older) { create(:session, fliip_service: service, user: trainer, occurred_at: 2.days.ago) }
      let!(:newer) { create(:session, fliip_service: service, user: other_trainer, occurred_at: 1.hour.ago) }
      let!(:future) { create(:session, fliip_service: service, user: trainer, occurred_at: 1.day.from_now) }

      before { sign_in create(:user, :manager) }

      def rows
        Nokogiri::HTML(response.body).css("a.recent-seance")
      end

      it "lists past séances newest first, each linking to its service, and leaves out future ones" do
        get recent_sessions_path

        expect(rows.size).to eq(2)
        expect(rows.map { |row| row["href"] }.uniq).to eq([ fliip_service_path(service) ])
        expect(rows.first.text).to include("Aline Côté", service.fliip_user.full_name, "Entraînement duo", "Présent·e", "1 h", "Non confirmée")
        expect(rows.last.text).to include("Ysolde Brisebois")
      end

      it "filters by trainer" do
        get recent_sessions_path(employee_id: trainer.id)

        expect(rows.size).to eq(1)
        expect(rows.first.text).to include("Ysolde Brisebois")
      end

      it "shows 50 séances, then the next ones on page 2" do
        big_service = create(:fliip_service, service_definition: create(:service_definition, paid_sessions: 100))
        50.times { |n| create(:session, fliip_service: big_service, user: trainer, occurred_at: (3 + n).hours.ago) }

        get recent_sessions_path
        expect(rows.size).to eq(50)
        expect(Nokogiri::HTML(response.body).at_css("a[rel=next]")["href"]).to eq(recent_sessions_path(page: 2))

        get recent_sessions_path(page: 2)
        expect(rows.size).to eq(2)
        expect(Nokogiri::HTML(response.body).at_css("a[rel=next]")).to be_nil
      end
    end
  end
end
