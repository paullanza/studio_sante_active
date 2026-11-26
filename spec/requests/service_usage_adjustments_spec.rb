require "rails_helper"

RSpec.describe "Service usage adjustments", type: :request do
  let(:service)     { create(:fliip_service, service_definition: create(:service_definition, paid_sessions: 10, free_sessions: 2)) }
  let(:employee)    { create(:user) }
  let(:admin)       { create(:user, :admin) }
  let(:turbo)       { { "Accept" => "text/vnd.turbo-stream.html, text/html" } }
  let!(:adjustment) { create(:service_usage_adjustment, fliip_service: service, user: employee, kind: :paid_used, amount: 1) }

  def adjustment_params(**overrides)
    { service_usage_adjustment: { kind: "paid_bonus", amount: "2", note: "Geste commercial", user_id: employee.id }.merge(overrides) }
  end

  it "redirects to sign-in when signed out" do
    post fliip_service_service_usage_adjustments_path(service), params: adjustment_params

    expect(response).to redirect_to(new_user_session_path)
  end

  %i[employee manager].each do |role|
    it "refuses a #{role} with the old redirect and message" do
      sign_in(role == :employee ? create(:user) : create(:user, role))

      expect { post fliip_service_service_usage_adjustments_path(service), params: adjustment_params }
        .not_to change(ServiceUsageAdjustment, :count)
      expect(response).to redirect_to(fliip_service_path(service))
      expect(flash[:alert]).to eq("Non autorisé·e.")

      get edit_fliip_service_service_usage_adjustment_path(service, adjustment)
      expect(response).to redirect_to(fliip_service_path(service))
      patch fliip_service_service_usage_adjustment_path(service, adjustment), params: adjustment_params
      expect(adjustment.reload).to have_attributes(kind: "paid_used", amount: 1.0)
      expect { delete fliip_service_service_usage_adjustment_path(service, adjustment) }
        .not_to change(ServiceUsageAdjustment, :count)
    end
  end

  it "refuses a manager's stream request with a 403" do
    sign_in create(:user, :manager)
    post fliip_service_service_usage_adjustments_path(service), params: adjustment_params, headers: turbo

    expect(response).to have_http_status(:forbidden)
  end

  describe "adding" do
    before { sign_in admin }

    {
      "paid_used" => ->(s) { s.paid_used_total },
      "free_used" => ->(s) { s.free_used_total },
      "paid_bonus" => ->(s) { s.paid_allowed_total },
      "free_bonus" => ->(s) { s.free_allowed_total }
    }.each do |kind, count|
      it "adds a « #{ServiceUsageAdjustment::KIND_LABELS[kind]} » adjustment and changes that count" do
        before_count = count.call(service.reload)

        post fliip_service_service_usage_adjustments_path(service), params: adjustment_params(kind: kind, amount: "1.5"), headers: turbo

        expect(response).to have_http_status(:ok)
        expect(ServiceUsageAdjustment.last).to have_attributes(kind: kind, amount: 1.5, note: "Geste commercial",
                                                                user: employee, created_by: admin)
        expect(count.call(service.reload)).to eq(before_count + 1.5)
      end
    end

    it "draws the list, the top card and the tab count again" do
      post fliip_service_service_usage_adjustments_path(service), params: adjustment_params, headers: turbo

      expect(response.body).to include(%(target="summary_fliip_service_#{service.id}"))
      expect(response.body).to include(%(target="adjustment_list_fliip_service_#{service.id}"))
      expect(response.body).to include(%(target="adjustments_count_fliip_service_#{service.id}"))
    end

    { "a missing note" => { note: "" }, "a zero" => { amount: "0" }, "a third of a séance" => { amount: "0.3" },
      "no kind" => { kind: "" } }.each do |label, overrides|
      it "refuses #{label} with a 422" do
        expect { post fliip_service_service_usage_adjustments_path(service), params: adjustment_params(**overrides), headers: turbo }
          .not_to change(ServiceUsageAdjustment, :count)
        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    it "lists the service in the trainer's Mes services" do
      trainer = create(:user)
      post fliip_service_service_usage_adjustments_path(service), params: adjustment_params(user_id: trainer.id), headers: turbo

      expect(FliipService.worked_on_by(trainer)).to include(service)
    end

    it "redirects plain HTML back to the tab" do
      post fliip_service_service_usage_adjustments_path(service), params: adjustment_params

      expect(response).to redirect_to(fliip_service_path(service, tab: "adjustments"))
      expect(flash[:notice]).to eq("Ajustement ajouté.")
    end
  end

  describe "editing and deleting in place" do
    before { sign_in admin }

    it "opens the edit card in the adjustment's frame, and « Annuler » gives the card back" do
      get edit_fliip_service_service_usage_adjustment_path(service, adjustment), headers: { "Turbo-Frame" => "service_usage_adjustment_#{adjustment.id}" }
      expect(response).to have_http_status(:ok)

      get fliip_service_service_usage_adjustment_path(service, adjustment), headers: { "Turbo-Frame" => "service_usage_adjustment_#{adjustment.id}" }
      expect(response).to have_http_status(:ok)
    end

    it "saves a change and refreshes the counts" do
      patch fliip_service_service_usage_adjustment_path(service, adjustment), params: adjustment_params(kind: "paid_used", amount: "3"), headers: turbo

      expect(adjustment.reload).to have_attributes(amount: 3.0, note: "Geste commercial")
      expect(service.reload.paid_used_total).to eq(3.0)
      expect(response.body).to include(%(target="summary_fliip_service_#{service.id}"))
    end

    it "gives the edit card back with a 422 on a bad amount" do
      patch fliip_service_service_usage_adjustment_path(service, adjustment), params: adjustment_params(amount: "0"), headers: turbo

      expect(response).to have_http_status(:unprocessable_content)
      expect(adjustment.reload.amount).to eq(1.0)
    end

    it "deletes and refreshes the counts" do
      expect { delete fliip_service_service_usage_adjustment_path(service, adjustment), headers: turbo }
        .to change(ServiceUsageAdjustment, :count).by(-1)
      expect(service.reload.paid_used_total).to eq(0.0)
      expect(response.body).to include(%(target="adjustment_list_fliip_service_#{service.id}"))
    end
  end

  it "never assigns an adjustment to the super admin" do
    super_admin = create(:user, :super_admin)
    sign_in admin

    expect { post fliip_service_service_usage_adjustments_path(service), params: adjustment_params(user_id: super_admin.id), headers: turbo }
      .not_to change(ServiceUsageAdjustment, :count)

    patch fliip_service_service_usage_adjustment_path(service, adjustment), params: adjustment_params(user_id: super_admin.id), headers: turbo
    expect(response).to have_http_status(:unprocessable_content)
    expect(adjustment.reload.user).to eq(employee)
  end

  # The adjustments tab and form are only visible in the markup.
  it "shows managers the adjustments tab without the add form" do
    sign_in create(:user, :manager)
    get fliip_service_path(service, tab: "adjustments")

    expect(response.body).to include("tab=adjustments")
    expect(response.body).not_to include("Ajouter un ajustement")
  end

  it "hides the adjustments tab from employees" do
    sign_in create(:user)
    get fliip_service_path(service)

    expect(response.body).not_to include("tab=adjustments")
  end
end
