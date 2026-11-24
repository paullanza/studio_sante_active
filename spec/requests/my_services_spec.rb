require "rails_helper"

RSpec.describe "Mes services", type: :request do
  let(:me) { create(:user) }

  # The séance is logged while the service is active; Fliip sets the status afterwards.
  def service_with_my_session(purchase_status: "A", **attrs)
    service = create(:fliip_service, **attrs)
    create(:session, user: me, fliip_service: service)
    service.update!(purchase_status: purchase_status)
    service
  end

  def listed_service_ids
    Nokogiri::HTML(response.body).css("a.service-card").map { |a| a["href"][%r{/fliip_services/(\d+)}, 1].to_i }
  end

  it "redirects to sign-in when signed out" do
    get my_services_path

    expect(response).to redirect_to(new_user_session_path)
  end

  %i[employee manager admin super_admin].each do |role|
    it "opens the page for a #{role}" do
      sign_in user_for(role)

      get my_services_path

      expect(response).to have_http_status(:ok)
    end
  end

  context "when signed in" do
    before { sign_in me }

    it "lists only my services, soonest end date first" do
      later = service_with_my_session(expire_date: 90.days.from_now.to_date)
      sooner = service_with_my_session(expire_date: 20.days.from_now.to_date)
      adjusted = create(:service_usage_adjustment, user: me, fliip_service: create(:fliip_service, expire_date: 50.days.from_now.to_date)).fliip_service
      create(:session, fliip_service: create(:fliip_service))

      get my_services_path

      expect(listed_service_ids).to eq([ sooner.id, adjusted.id, later.id ])
    end

    it "shows active, planned and suspended services by default" do
      shown = %w[A P S].map { |code| service_with_my_session(purchase_status: code) }
      service_with_my_session(purchase_status: "I")
      service_with_my_session(purchase_status: "C")

      get my_services_path

      expect(listed_service_ids).to match_array(shown.map(&:id))
    end

    it "adds inactive services with « Inactifs »" do
      active = service_with_my_session(purchase_status: "A")
      inactive = service_with_my_session(purchase_status: "I")
      service_with_my_session(purchase_status: "C")

      get my_services_path, params: { inactifs: "1" }

      expect(listed_service_ids).to contain_exactly(active.id, inactive.id)
    end

    it "adds cancelled services with « Annulés »" do
      active = service_with_my_session(purchase_status: "A")
      cancelled = service_with_my_session(purchase_status: "C")
      service_with_my_session(purchase_status: "I")

      get my_services_path, params: { annules: "1" }

      expect(listed_service_ids).to contain_exactly(active.id, cancelled.id)
    end

    it "shows the empty state when I have no services" do
      get my_services_path

      expect(response.body).to include("Aucun service pour l'instant.")
    end
  end
end
