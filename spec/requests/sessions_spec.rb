require "rails_helper"

RSpec.describe "Sessions", type: :request do
  let(:employee) { create(:user) }
  let(:service)  { create(:fliip_service) }

  def session_params(**overrides)
    {
      session: {
        fliip_user_id: service.fliip_user_id,
        fliip_service_id: service.id,
        date: Date.current.iso8601,
        time: "10:00",
        present: "1"
      }.merge(overrides)
    }
  end

  describe "POST /sessions" do
    it "creates a paid session for the signed-in employee" do
      sign_in employee

      expect { post sessions_path, params: session_params }.to change(Session, :count).by(1)

      session = Session.last
      expect(session.user).to eq(employee)
      expect(session.created_by).to eq(employee)
      expect(session).to be_paid
      expect(session).not_to be_confirmed
      expect(response).to redirect_to(new_seance_path)
    end

    it "records a half-hour session" do
      sign_in employee
      post sessions_path, params: session_params.merge(half_hour: "1")

      expect(Session.last.duration).to eq(0.5)
    end

    it "ignores user_id from employees" do
      other = create(:user)
      sign_in employee
      post sessions_path, params: session_params(user_id: other.id)

      expect(Session.last.user).to eq(employee)
    end

    it "lets admins book for another employee" do
      sign_in create(:user, :admin)
      post sessions_path, params: session_params(user_id: employee.id)

      expect(Session.last.user).to eq(employee)
    end

    it "re-renders the form with an error when the service is cancelled" do
      service.update!(purchase_status: "C")
      sign_in employee

      expect { post sessions_path, params: session_params }.not_to change(Session, :count)
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "PATCH /sessions/:id and DELETE /sessions/:id" do
    let!(:session_record) { create(:session, fliip_service: service, user: employee, note: "original") }

    it "lets the owner update their unconfirmed session" do
      sign_in employee
      patch session_path(session_record),
            params: { session: { note: "updated", present: "1",
                                 date: Date.current.iso8601, time: "11:00" } }

      expect(response).to have_http_status(:ok)
      expect(session_record.reload.note).to eq("updated")
    end

    it "refuses updates from another employee" do
      sign_in create(:user)
      patch session_path(session_record), params: { session: { note: "hacked" } }

      expect(session_record.reload.note).to eq("original")
    end

    it "refuses deletes from another employee" do
      sign_in create(:user)

      expect { delete session_path(session_record) }.not_to change(Session, :count)
    end

    it "lets admins delete confirmed sessions" do
      session_record.update_columns(confirmed: true)
      sign_in create(:user, :admin)

      expect { delete session_path(session_record) }.to change(Session, :count).by(-1)
    end
  end
end
