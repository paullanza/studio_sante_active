class FliipServicesController < ApplicationController
  before_action :authenticate_user!

  def show
    @service = FliipService
                 .includes(
                   :fliip_user,
                   :service_definition,
                   :service_usage_adjustments,
                   consultation: [:user, :fliip_user, :fliip_service]
                 )
                 .find(params[:id])

    @adjustments = @service.service_usage_adjustments.includes(:user).order(created_at: :desc)
    @sessions    = @service.sessions.includes(:user, :fliip_user).order_by_occurred_at_desc
  end
end
