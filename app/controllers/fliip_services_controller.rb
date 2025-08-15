# app/controllers/fliip_services_controller.rb
class FliipServicesController < ApplicationController
  before_action :authenticate_user!

  def show
    @service = FliipService
                 .includes(:fliip_user, :service_definition)
                 .find(params[:id])

    scope = @service.sessions
                     .includes(:fliip_user, :fliip_service)
                     .order(Arel.sql("COALESCE(date, '0001-01-01') DESC"),
                            Arel.sql("COALESCE(time, '00:00:00') DESC"),
                            created_at: :desc)
    @pagy, @sessions = pagy(scope, items: 50)

    # Use model totals (sessions + adjustments)
    @paid_used  = @service.paid_used_total
    @free_used  = @service.free_used_total
    @paid_total = @service.service_definition&.paid_sessions
    @free_total = @service.service_definition&.free_sessions
    @paid_bonus = @service.paid_bonus_total

    @adjustments = @service.service_usage_adjustments.includes(:user).order(created_at: :desc)

    @status_label = {
      "A" => "Active", "I" => "Inactive", "P" => "Planned",
      "C" => "Cancelled", "S" => "Stopped"
    }[@service.purchase_status] || "-"
  end
end
