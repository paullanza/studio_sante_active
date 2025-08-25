class FliipServicesController < ApplicationController
  before_action :authenticate_user!

  def show
    @service = FliipService
                 .includes(:fliip_user, :service_definition, :service_usage_adjustments)
                 .find(params[:id])

    @adjustments = @service.service_usage_adjustments.includes(:user).order(created_at: :desc)

        # Paginate sessions
    @pagy, @sessions = pagy(
      @service.sessions.includes(:user, :fliip_user).order_by_occurred_at_desc,
      items: 25
    )
  end
end
