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
      expect(response).to redirect_to(new_seance_path)
    end

    it "re-renders the booking page when a required field is missing" do
      sign_in employee

      expect { post consultations_path, params: consultation_params(phone_number: "") }
        .not_to change(Consultation, :count)
      expect(response).to have_http_status(:unprocessable_content)
      expect(flash[:alert]).to be_present
    end
  end

  describe "GET /consultations/new" do
    it "is no longer routed" do
      expect { Rails.application.routes.recognize_path("/consultations/new", method: :get) }
        .to raise_error(ActionController::RoutingError)
    end
  end
end
