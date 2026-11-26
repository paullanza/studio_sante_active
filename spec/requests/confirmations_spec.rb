require "rails_helper"

RSpec.describe "Confirmations", type: :request do
  # The period 22 Nov – 5 Dec 2026 is current; 8–21 Nov is the one before.
  before { travel_to Time.zone.local(2026, 11, 26, 12, 0) }

  let(:admin) { create(:user, :admin) }
  let(:trainer) { create(:user, first_name: "Zoé", last_name: "Roy") }
  let(:service) do
    create(:fliip_service, purchase_date: Date.new(2026, 10, 1), start_date: Date.new(2026, 10, 1),
                           service_definition: create(:service_definition, paid_sessions: 20, free_sessions: 0))
  end

  # A séance at a given time, past the booking rules' date window.
  def seance_at(time, **attrs)
    create(:session, fliip_service: service, user: trainer, **attrs).tap { |s| s.update_columns(occurred_at: time) }
  end

  def listed_ids
    Nokogiri::HTML(response.body).css("input[name='session_ids[]']").map { |input| input["value"].to_i }
  end

  describe "GET /confirmations/seances" do
    %i[admin super_admin].each do |role|
      it "opens for #{role == :admin ? 'an admin' : 'the super admin'}" do
        sign_in create(:user, role)
        get session_confirmations_path

        expect(response).to have_http_status(:ok)
      end
    end

    %i[employee manager].each do |role|
      it "sends a #{role} back with the alert" do
        sign_in(role == :employee ? create(:user) : create(:user, role))
        get session_confirmations_path

        expect(response).to redirect_to(authenticated_root_path)
        expect(flash[:alert]).to eq("Non autorisé·e.")
      end
    end

    it "lists the chosen period's unconfirmed séances, and none across its edges" do
      last_of_previous = seance_at(Time.zone.local(2026, 11, 21, 18, 0))
      first_of_current = seance_at(Time.zone.local(2026, 11, 22, 9, 0))
      sign_in admin

      get session_confirmations_path
      # The list is only visible in the markup.
      expect(listed_ids).to eq([ first_of_current.id ])

      get session_confirmations_path(periode: "2026-11-08")
      expect(listed_ids).to eq([ last_of_previous.id ])
    end

    it "filters by trainer" do
      mine = seance_at(Time.zone.local(2026, 11, 23, 9, 0))
      seance_at(Time.zone.local(2026, 11, 23, 10, 0), user: create(:user))
      sign_in admin

      get session_confirmations_path(employee_id: trainer.id)

      expect(listed_ids).to eq([ mine.id ])
    end

    it "points to the oldest earlier period that still has unconfirmed séances" do
      seance_at(Time.zone.local(2026, 10, 30, 9, 0))
      seance_at(Time.zone.local(2026, 11, 10, 9, 0))
      sign_in admin

      get session_confirmations_path

      expect(response.body).to include("2 séance(s) non confirmée(s) dans des périodes précédentes")
      expect(response.body).to include(session_confirmations_path(periode: "2026-10-25"))
    end
  end

  describe "PATCH /confirmations/seances" do
    it "confirms the chosen séances, records who did, and keeps the period" do
      seance = seance_at(Time.zone.local(2026, 11, 10, 9, 0))
      sign_in admin

      patch confirm_session_confirmations_path, params: { session_ids: [ seance.id ], periode: "2026-11-08" }

      expect(seance.reload).to have_attributes(confirmed: true, confirmed_by: admin)
      expect(response).to redirect_to(session_confirmations_path(periode: "2026-11-08"))
      expect(flash[:notice]).to eq("1 séance(s) confirmée(s).")
    end

    it "warns when nothing was chosen" do
      sign_in admin
      patch confirm_session_confirmations_path

      expect(flash[:alert]).to eq("Aucune séance sélectionnée.")
    end

    it "refuses a manager" do
      seance = seance_at(Time.zone.local(2026, 11, 23, 9, 0))
      sign_in create(:user, :manager)

      patch confirm_session_confirmations_path, params: { session_ids: [ seance.id ] }

      expect(seance.reload).not_to be_confirmed
    end
  end

  describe "editing a séance in place from Confirmations" do
    it "gives the confirmation row back after a save" do
      seance = seance_at(Time.zone.local(2026, 11, 23, 9, 0))
      sign_in admin

      patch session_path(seance), params: { context: "confirmations", session: { note: "vu", present: "1", duration: "1.0", date: "2026-11-23", time: "09:00" } },
                                  headers: { "Accept" => "text/vnd.turbo-stream.html, text/html" }

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(seance.reload.note).to eq("vu")
    end

    it "removes the row and updates the trainer's count after « Supprimer »" do
      seance = seance_at(Time.zone.local(2026, 11, 23, 9, 0))
      seance_at(Time.zone.local(2026, 11, 24, 9, 0))
      sign_in admin

      delete session_path(seance), params: { context: "confirmations" },
                                   headers: { "Accept" => "text/vnd.turbo-stream.html, text/html" }

      expect(Session.exists?(seance.id)).to be(false)
      expect(response.body).to include(%(action="remove" target="item_session_#{seance.id}"))
      expect(response.body).to include("1 séance(s)")
    end

    it "removes the trainer's group with their last séance" do
      seance = seance_at(Time.zone.local(2026, 11, 23, 9, 0))
      sign_in admin

      delete session_path(seance), params: { context: "confirmations" },
                                   headers: { "Accept" => "text/vnd.turbo-stream.html, text/html" }

      expect(response.body).to include(%(target="confirm_section_user_#{trainer.id}"))
    end

    it "gives the row back on « Annuler »" do
      seance = seance_at(Time.zone.local(2026, 11, 23, 9, 0))
      sign_in admin

      get row_session_path(seance, context: "confirmations"), headers: { "Turbo-Frame" => "session_#{seance.id}" }

      expect(response).to have_http_status(:ok)
    end
  end
end
