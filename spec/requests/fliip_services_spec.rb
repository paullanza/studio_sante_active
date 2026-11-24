require "rails_helper"

RSpec.describe "Fliip services", type: :request do
  let(:service) { create(:fliip_service) }

  it "redirects to sign-in when signed out" do
    get fliip_service_path(service)

    expect(response).to redirect_to(new_user_session_path)
  end

  %i[employee manager admin super_admin].each do |role|
    it "shows a service to a #{role}" do
      sign_in(role == :employee ? create(:user) : create(:user, role))

      get fliip_service_path(service)

      expect(response).to have_http_status(:ok)
    end
  end

  it "answers 404 for an unknown service" do
    sign_in create(:user)

    get fliip_service_path(0)

    expect(response).to have_http_status(:not_found)
  end

  describe "tabs" do
    let(:definition) { create(:service_definition, paid_sessions: 10, free_sessions: 2) }
    let(:service)    { create(:fliip_service, service_definition: definition) }
    let(:trainer)    { create(:user, first_name: "Thoren", last_name: "Lachance") }
    let!(:seance)    { create(:session, fliip_service: service, user: trainer, occurred_at: 2.days.ago.change(hour: 17, min: 0)) }
    let!(:consultation) { create(:consultation, fliip_service: service, fliip_user: service.fliip_user, user: trainer) }
    let!(:adjustment)   { create(:service_usage_adjustment, fliip_service: service, user: trainer, bonus_sessions: 2) }

    def page
      Nokogiri::HTML(response.body)
    end

    def current_tab
      page.at_css(".tabs__tab[aria-current=page]").text
    end

    it "shows the séances by default, numbered" do
      sign_in create(:user)

      get fliip_service_path(service)

      expect(current_tab).to eq("Séances (1)")
      expect(page.at_css(".seance-card__title").text).to eq("Séance #1")
      expect(page.at_css(".seance-card .badge--chargee").text).to eq("Chargée")
    end

    it "lists the linked consultation" do
      sign_in create(:user)

      get fliip_service_path(service, tab: "consultations")

      expect(current_tab).to eq("Consultations (1)")
      expect(page.css(".seance-card").size).to eq(1)
    end

    it "shows managers the adjustments without the form or the actions" do
      sign_in create(:user, :manager)

      get fliip_service_path(service, tab: "adjustments")

      expect(current_tab).to eq("Ajustements (1)")
      expect(page.at_css(".seance-card dd").text).to eq("2")
      expect(page.at_css("form[action='#{fliip_service_service_usage_adjustments_path(service)}']")).to be_nil
      expect(page.at_css(".adjustment-card__actions")).to be_nil
    end

    it "gives admins the actions and the add form" do
      sign_in create(:user, :admin)

      get fliip_service_path(service, tab: "adjustments")

      expect(page.at_css(".adjustment-card__actions a").text).to eq("Modifier")
      expect(page.at_css("form[action='#{fliip_service_service_usage_adjustments_path(service)}'] select#service_usage_adjustment_user_id")).to be_present
    end

    it "gives an employee asking for the adjustments the séances tab" do
      sign_in create(:user)

      get fliip_service_path(service, tab: "adjustments")

      expect(current_tab).to eq("Séances (1)")
      expect(page.css(".tabs__tab").map(&:text)).to eq([ "Séances (1)", "Consultations (1)" ])
    end

    it "shows the empty states" do
      sign_in create(:user, :admin)
      empty = create(:fliip_service)

      %w[sessions consultations adjustments].zip([ "Aucune séance.", "Aucune consultation.", "Aucun ajustement sur ce service." ]).each do |tab, text|
        get fliip_service_path(empty, tab: tab)
        expect(page.at_css(".empty-state").text).to eq(text)
      end
    end
  end

  describe "« Saisir une séance »" do
    def gold_button
      Nokogiri::HTML(response.body).at_css("a.btn--primary")
    end

    def block_reason
      Nokogiri::HTML(response.body).at_css(".service-page__blocked")&.text
    end

    before { sign_in create(:user) }

    it "opens Saisir with the client and the service chosen" do
      get fliip_service_path(service)

      expect(gold_button["href"]).to eq(new_seance_path(fliip_user_id: service.fliip_user_id, fliip_service_id: service.id))
      expect(block_reason).to be_nil
    end

    it "gives the reason instead for a fully used service" do
      used_up = create(:fliip_service, service_definition: create(:service_definition, paid_sessions: 1, free_sessions: 0))
      create(:service_usage_adjustment, fliip_service: used_up, paid_used_delta: 1)

      get fliip_service_path(used_up)

      expect(gold_button).to be_nil
      expect(block_reason).to eq("Toutes les séances utilisées")
    end

    it "gives the reason instead for a service removed from Fliip" do
      get fliip_service_path(create(:fliip_service, :missing_from_fliip))

      expect(gold_button).to be_nil
      expect(block_reason).to eq("Retiré de Fliip")
    end
  end
end
