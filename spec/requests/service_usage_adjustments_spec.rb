require "rails_helper"

RSpec.describe "Service usage adjustments", type: :request do
  let(:service)    { create(:fliip_service) }
  let(:employee)   { create(:user) }
  let!(:adjustment) { create(:service_usage_adjustment, fliip_service: service, user: employee, paid_used_delta: 1) }

  def adjustment_params(**overrides)
    { service_usage_adjustment: { bonus_sessions: 2, paid_used_delta: 0, user_id: employee.id }.merge(overrides) }
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
      expect(flash[:alert]).to eq("Not authorized.")

      get edit_fliip_service_service_usage_adjustment_path(service, adjustment)
      expect(response).to redirect_to(fliip_service_path(service))
      patch fliip_service_service_usage_adjustment_path(service, adjustment), params: adjustment_params
      expect(adjustment.reload.bonus_sessions).to eq(0)
      expect { delete fliip_service_service_usage_adjustment_path(service, adjustment) }
        .not_to change(ServiceUsageAdjustment, :count)
    end
  end

  %i[admin super_admin].each do |role|
    it "lets #{role == :admin ? 'an admin' : 'the super admin'} add, edit and delete adjustments" do
      sign_in create(:user, role)

      expect { post fliip_service_service_usage_adjustments_path(service), params: adjustment_params }
        .to change(ServiceUsageAdjustment, :count).by(1)
      expect(ServiceUsageAdjustment.last.user).to eq(employee)

      get edit_fliip_service_service_usage_adjustment_path(service, adjustment)
      expect(response).to have_http_status(:ok)
      patch fliip_service_service_usage_adjustment_path(service, adjustment), params: adjustment_params(bonus_sessions: 3)
      expect(adjustment.reload.bonus_sessions).to eq(3)

      expect { delete fliip_service_service_usage_adjustment_path(service, adjustment) }
        .to change(ServiceUsageAdjustment, :count).by(-1)
    end
  end

  it "never assigns an adjustment to the super admin" do
    super_admin = create(:user, :super_admin)
    sign_in create(:user, :admin)

    expect { post fliip_service_service_usage_adjustments_path(service), params: adjustment_params(user_id: super_admin.id) }
      .not_to change(ServiceUsageAdjustment, :count)

    patch fliip_service_service_usage_adjustment_path(service, adjustment), params: adjustment_params(user_id: super_admin.id)
    expect(response).to have_http_status(:unprocessable_content)
    expect(adjustment.reload.user).to eq(employee)
  end

  it "reports an empty adjustment" do
    sign_in create(:user, :admin)

    post fliip_service_service_usage_adjustments_path(service), params: adjustment_params(bonus_sessions: 0)

    expect(flash[:alert]).to eq("Provide at least one non-zero adjustment.")
  end

  # The adjustments tab and form are only visible in the markup.
  it "shows managers the adjustments tab without the add form" do
    sign_in create(:user, :manager)
    get fliip_service_path(service)

    expect(response.body).to include("pane-adjustments")
    expect(response.body).not_to include("Ajouter un ajustement")
  end

  it "hides the adjustments tab from employees" do
    sign_in create(:user)
    get fliip_service_path(service)

    expect(response.body).not_to include("pane-adjustments")
  end
end
