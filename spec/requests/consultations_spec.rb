require "rails_helper"

RSpec.describe "Consultations", type: :request do
  let(:employee) { create(:user) }

  def consultation_params(**overrides)
    {
      consultation: {
        first_name: "Jo",
        last_name: "Tremblay",
        phone_number: "514-555-0100",
        date: Date.current.iso8601,
        time: "10:00",
        present: "1"
      }.merge(overrides)
    }
  end

  describe "POST /consultations" do
    it "creates a consultation for the signed-in employee" do
      sign_in employee

      expect { post consultations_path, params: consultation_params }.to change(Consultation, :count).by(1)

      expect(Consultation.last.user).to eq(employee)
      expect(response).to redirect_to(new_seance_path(tab: "consultation"))
      expect(flash[:notice]).to eq("Consultation enregistrée.")
    end

    it "re-renders the booking page when a required field is missing" do
      sign_in employee

      expect { post consultations_path, params: consultation_params(first_name: "") }
        .not_to change(Consultation, :count)
      expect(response).to have_http_status(:unprocessable_content)
      # The error shows on the field, only visible in the markup.
      expect(Nokogiri::HTML(response.body).at_css("#consultation_first_name_error")).to be_present
    end

    it "saves with an email only" do
      sign_in employee

      expect { post consultations_path, params: consultation_params(phone_number: "", email: "jo@exemple.ca") }
        .to change(Consultation, :count).by(1)
      expect(Consultation.last).to have_attributes(phone_number: nil, email: "jo@exemple.ca")
    end

    it "refuses a consultation with neither phone nor email" do
      sign_in employee

      expect { post consultations_path, params: consultation_params(phone_number: "", email: "") }
        .not_to change(Consultation, :count)
      expect(response).to have_http_status(:unprocessable_content)
      # The error shows above the form, only visible in the markup.
      expect(response.body).to include("Indiquez un téléphone ou un courriel.")
    end

    it "stores the phone as 10 digits" do
      sign_in employee
      post consultations_path, params: consultation_params(phone_number: "1 (514) 555-0142")

      expect(Consultation.last.phone_number).to eq("5145550142")
    end

    it "refuses a consultation without presence" do
      sign_in employee
      params = consultation_params
      params[:consultation].delete(:present)

      expect { post consultations_path, params: params }.not_to change(Consultation, :count)
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "lists my latest consultations on the consultation tab" do
      create(:consultation, user: employee, first_name: "Récente")
      sign_in employee

      get new_seance_path(tab: "consultation")

      expect(response).to have_http_status(:ok)
      # The list is only visible in the markup.
      expect(Nokogiri::HTML(response.body).css(".consultation-card").size).to eq(1)
    end
  end

  describe "GET /consultations/new" do
    it "is no longer routed" do
      expect { Rails.application.routes.recognize_path("/consultations/new", method: :get) }
        .to raise_error(ActionController::RoutingError)
    end
  end

  context "when signed out" do
    it "redirects to sign-in" do
      consultation = create(:consultation)

      post consultations_path, params: consultation_params
      expect(response).to redirect_to(new_user_session_path)
      get edit_consultation_path(consultation)
      expect(response).to redirect_to(new_user_session_path)
      get associations_consultations_path
      expect(response).to redirect_to(new_user_session_path)
    end
  end

  describe "choosing the employee on create" do
    let(:super_admin) { create(:user, :super_admin) }

    it "ignores user_id from employees and managers" do
      manager = create(:user, :manager)

      sign_in employee
      post consultations_path, params: consultation_params(user_id: manager.id)
      expect(Consultation.last.user).to eq(employee)

      sign_in manager
      post consultations_path, params: consultation_params(user_id: employee.id, time: "11:00")
      expect(Consultation.last.user).to eq(manager)
    end

    it "lets admins create for an employee, but never for the super admin" do
      sign_in create(:user, :admin)

      post consultations_path, params: consultation_params(user_id: employee.id)
      expect(Consultation.last.user).to eq(employee)

      expect { post consultations_path, params: consultation_params(user_id: super_admin.id) }
        .not_to change(Consultation, :count)
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "requires the super admin to choose an employee" do
      sign_in super_admin

      expect { post consultations_path, params: consultation_params }.not_to change(Consultation, :count)
      # The error shows above the form, only visible in the markup.
      expect(response.body).to include("Veuillez choisir un·e employé·e.")

      post consultations_path, params: consultation_params(user_id: employee.id)
      expect(Consultation.last).to have_attributes(user: employee, created_by: super_admin)
    end
  end

  describe "editing by role" do
    let(:manager) { create(:user, :manager) }
    let!(:own)    { create(:consultation, user: employee, first_name: "Avant") }
    let!(:confirmed) { create(:consultation, user: employee, confirmed: true) }
    let!(:managers_own) { create(:consultation, user: manager) }

    def update_params(**overrides)
      { consultation: { first_name: "Après", last_name: "Roy", phone_number: "514-555-0100",
                        date: Date.current.iso8601, time: "10:00", present: "1" }.merge(overrides) }
    end

    it "lets employees edit their own unconfirmed consultation only" do
      sign_in employee

      get edit_consultation_path(own)
      expect(response).to have_http_status(:ok)
      patch consultation_path(own), params: update_params(user_id: manager.id)
      expect(own.reload).to have_attributes(first_name: "Après", user: employee)

      get edit_consultation_path(confirmed)
      expect(response).to redirect_to(new_seance_path(tab: "consultation"))
      expect(flash[:alert]).to eq("Non autorisé·e.")
      expect { delete consultation_path(confirmed), headers: { "Accept" => "application/json" } }
        .not_to change(Consultation, :count)
      expect(response).to have_http_status(:forbidden)
    end

    it "lets managers edit only their own" do
      sign_in manager

      patch consultation_path(managers_own), params: update_params
      expect(managers_own.reload.first_name).to eq("Après")
      patch consultation_path(own), params: update_params(first_name: "Manager")
      expect(own.reload.first_name).to eq("Avant")
    end

    it "lets admins and the super admin edit any consultation and reassign it" do
      other = create(:user)

      sign_in create(:user, :admin)
      patch consultation_path(confirmed), params: update_params(user_id: other.id)
      expect(confirmed.reload.user).to eq(other)

      sign_in create(:user, :super_admin)
      expect { delete consultation_path(managers_own) }.to change(Consultation, :count).by(-1)
    end

    it "refuses to reassign a consultation to the super admin" do
      super_admin = create(:user, :super_admin)
      sign_in create(:user, :admin)

      patch consultation_path(own), params: update_params(user_id: super_admin.id)

      expect(response).to have_http_status(:unprocessable_content)
      expect(own.reload.user).to eq(employee)
    end

    it "serves the row to every signed-in user" do
      sign_in create(:user)
      get row_consultation_path(own)

      expect(response).to have_http_status(:ok)
    end
  end

  describe "editing in place (Saisir, Client and Service pages)" do
    let(:stream) { { "Accept" => "text/vnd.turbo-stream.html, text/html, application/xhtml+xml" } }
    let(:client) { create(:fliip_user) }
    let(:service) { create(:fliip_service, fliip_user: client) }
    let!(:own) { create(:consultation, user: employee, first_name: "Avant", fliip_user: client, fliip_service: service) }

    def update_params(**overrides)
      { consultation: { first_name: "Après", last_name: "Roy", phone_number: "514-555-0100",
                        date: Date.current.iso8601, time: "10:00", present: "0" }.merge(overrides) }
    end

    it "opens the edit card in the consultation's frame" do
      sign_in employee
      get edit_consultation_path(own, context: "client"), headers: { "Turbo-Frame" => "consultation_#{own.id}" }

      expect(response).to have_http_status(:ok)
    end

    it "gives the card back on « Annuler »" do
      sign_in employee
      get row_consultation_path(own, context: "saisir"), headers: { "Turbo-Frame" => "consultation_#{own.id}" }

      expect(response).to have_http_status(:ok)
    end

    it "lets the owner update an unconfirmed consultation, answering with a stream" do
      sign_in employee
      patch consultation_path(own), params: update_params.merge(context: "service"), headers: stream

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(own.reload).to have_attributes(first_name: "Après", present: false, phone_number: "5145550100")
    end

    it "refuses the owner once the consultation is confirmed" do
      own.update_columns(confirmed: true)
      sign_in employee
      patch consultation_path(own), params: update_params, headers: stream

      expect(response).to have_http_status(:forbidden)
      expect(own.reload.first_name).to eq("Avant")
    end

    it "refuses another employee" do
      sign_in create(:user)
      patch consultation_path(own), params: update_params, headers: stream

      expect(response).to have_http_status(:forbidden)
      expect(own.reload.first_name).to eq("Avant")
    end

    it "lets an admin update a confirmed consultation" do
      own.update_columns(confirmed: true)
      sign_in create(:user, :admin)
      patch consultation_path(own), params: update_params, headers: stream

      expect(response).to have_http_status(:ok)
      expect(own.reload.first_name).to eq("Après")
    end

    it "refuses a phone that isn't 10 digits" do
      sign_in employee
      patch consultation_path(own), params: update_params(phone_number: "555-0100"), headers: stream

      expect(response).to have_http_status(:unprocessable_content)
      expect(own.reload.first_name).to eq("Avant")
    end

    it "refuses an edit with neither phone nor email" do
      sign_in employee
      patch consultation_path(own), params: update_params(phone_number: "", email: ""), headers: stream

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "deletes with a stream, from each page" do
      other = create(:consultation, user: employee, fliip_user: client)
      sign_in employee

      expect { delete consultation_path(own), params: { context: "service" }, headers: stream }.to change(Consultation, :count).by(-1)
      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")

      expect { delete consultation_path(other), params: { context: "client" }, headers: stream }.to change(Consultation, :count).by(-1)
      expect(response).to have_http_status(:ok)
    end

    it "still answers the old pages with their rows" do
      sign_in employee

      get edit_consultation_path(own)
      expect(response).to have_http_status(:ok)
      get row_consultation_path(own)
      expect(response).to have_http_status(:ok)
      patch consultation_path(own), params: update_params
      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("text/html")
    end
  end

  describe "association" do
    let(:client)  { create(:fliip_user, user_firstname: "Léa", user_lastname: "Roy") }
    let(:service) { create(:fliip_service, fliip_user: client, purchase_date: 1.day.ago) }
    let(:turbo)   { { "Accept" => "text/vnd.turbo-stream.html, text/html" } }
    let(:frame)   { { "Turbo-Frame" => "consultation_#{consultation.id}" } }
    let!(:consultation) do
      create(:consultation, user: employee, first_name: "Léa", last_name: "Roy", occurred_at: Time.current, confirmed: true)
    end

    def associate(service_id: service.id, context: "lier")
      patch associate_consultation_path(consultation), params: { fliip_user_id: client.id, fliip_service_id: service_id, context: context },
                                                       headers: turbo
    end

    def listed_ids
      Nokogiri::HTML(response.body).css(".consultation-card").map { |card| card.ancestors("turbo-frame").first["id"] }
    end

    it "is closed to employees, even on their own consultation" do
      sign_in employee

      get association_consultation_path(consultation)
      expect(response).to redirect_to(new_seance_path(tab: "consultation"))
      associate
      expect(consultation.reload.fliip_service).to be_nil
      get associations_consultations_path
      expect(response).to redirect_to(new_seance_path(tab: "consultation"))
    end

    %i[manager admin super_admin].each do |role|
      it "opens « Lier les consultations » for #{role}" do
        sign_in create(:user, role)
        get associations_consultations_path

        expect(response).to have_http_status(:ok)
      end
    end

    it "lists the consultations without a service, filtered by trainer and dates" do
      linked = create(:consultation, fliip_user: client, fliip_service: service)
      other_trainer = create(:consultation, occurred_at: Time.current)
      old = create(:consultation, user: employee, occurred_at: 2.months.ago)
      sign_in create(:user, :manager)

      get associations_consultations_path
      # The list is only visible in the markup.
      expect(listed_ids).to include("consultation_#{consultation.id}", "consultation_#{other_trainer.id}", "consultation_#{old.id}")
      expect(listed_ids).not_to include("consultation_#{linked.id}")

      get associations_consultations_path(employee_id: employee.id, consultation_date_from: 1.week.ago.to_date.iso8601)
      expect(listed_ids).to eq([ "consultation_#{consultation.id}" ])
    end

    it "opens the link form on the best name match, or on the client asked for" do
      service
      other = create(:fliip_user, user_firstname: "Marc", user_lastname: "Tremblay")
      sign_in create(:user, :manager)

      get association_consultation_path(consultation, context: "lier"), headers: frame
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(fliip_user_path(client))

      get association_consultation_path(consultation, fliip_user_id: other.id, context: "lier"), headers: frame
      expect(response.body).to include(fliip_user_path(other))
    end

    it "links a service already linked to another consultation, and removes the card from the list" do
      create(:consultation, fliip_user: client, fliip_service: service)
      sign_in create(:user, :manager)

      associate

      expect(consultation.reload).to have_attributes(fliip_user: client, fliip_service: service)
      expect(response.body).to include(%(action="remove" target="item_consultation_#{consultation.id}"))
    end

    it "refuses a service bought outside the link window with a 422" do
      late = create(:fliip_service, fliip_user: client, purchase_date: 31.days.from_now)
      sign_in create(:user, :admin)

      associate(service_id: late.id)

      expect(response).to have_http_status(:unprocessable_content)
      expect(consultation.reload.fliip_service).to be_nil
    end

    it "links the client alone and keeps the card on the list" do
      sign_in create(:user, :admin)

      associate(service_id: "")

      expect(consultation.reload).to have_attributes(fliip_user: client, fliip_service: nil)
      expect(Consultation.to_link).to include(consultation)
      expect(response.body).to include(%(action="replace" target="consultation_#{consultation.id}"))
    end

    it "lets only admins and the super admin disassociate" do
      consultation.update!(fliip_user: client, fliip_service: service)

      [ employee, create(:user, :manager) ].each do |user|
        sign_in user
        patch disassociate_consultation_path(consultation), headers: turbo
        expect(consultation.reload.fliip_service).to eq(service)
      end

      sign_in create(:user, :super_admin)
      patch disassociate_consultation_path(consultation), params: { context: "service" }, headers: turbo

      expect(consultation.reload).to have_attributes(fliip_service: nil, fliip_user: nil)
      expect(response.body).to include(%(action="replace" target="consultation_#{consultation.id}"))
    end

    it "leaves the super admin out of the associations employee filter" do
      super_admin = create(:user, :super_admin)
      sign_in create(:user, :manager)

      get associations_consultations_path

      # The filter options are only visible in the markup.
      expect(response.body).to include(%(value="#{employee.id}"))
      expect(response.body).not_to include(%(value="#{super_admin.id}"))
    end
  end
  describe "GET /consultations" do
    let(:client)  { create(:fliip_user) }
    let(:service) { create(:fliip_service, fliip_user: client, purchase_date: 1.day.ago) }
    let!(:to_link) { create(:consultation, user: employee, occurred_at: 2.days.ago) }
    let!(:linked)  { create(:consultation, fliip_user: client, fliip_service: service, occurred_at: 1.day.ago) }
    let!(:old)     { create(:consultation, user: employee, occurred_at: 40.days.ago) }

    def listed_ids
      Nokogiri::HTML(response.body).css(".consultation-card").map { |card| card.ancestors("turbo-frame").first["id"] }
    end

    it "is closed to employees" do
      sign_in employee
      get consultations_path

      expect(response).to redirect_to(new_seance_path(tab: "consultation"))
    end

    %i[manager admin super_admin].each do |role|
      it "lists the last 30 days, newest first, for #{role}" do
        sign_in create(:user, role)
        get consultations_path

        expect(response).to have_http_status(:ok)
        # The list is only visible in the markup.
        expect(listed_ids).to eq([ "consultation_#{linked.id}", "consultation_#{to_link.id}" ])
      end
    end

    it "shows every date once « Du » is emptied" do
      sign_in create(:user, :manager)
      get consultations_path(consultation_date_from: "")

      expect(listed_ids).to include("consultation_#{old.id}")
    end

    it "filters by status and by trainer" do
      sign_in create(:user, :manager)

      get consultations_path(status: "to_link")
      expect(listed_ids).to eq([ "consultation_#{to_link.id}" ])

      get consultations_path(status: "linked")
      expect(listed_ids).to eq([ "consultation_#{linked.id}" ])

      get consultations_path(employee_id: linked.user_id)
      expect(listed_ids).to eq([ "consultation_#{linked.id}" ])
    end

    it "keeps a linked card on the list" do
      other = create(:fliip_service, fliip_user: client, purchase_date: 1.day.ago)
      sign_in create(:user, :manager)

      patch associate_consultation_path(to_link), params: { fliip_user_id: client.id, fliip_service_id: other.id, context: "consultations" },
                                                  headers: { "Accept" => "text/vnd.turbo-stream.html, text/html" }

      expect(to_link.reload.fliip_service).to eq(other)
      expect(response.body).to include(%(action="replace" target="consultation_#{to_link.id}"))
    end
  end
end
