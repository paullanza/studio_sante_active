# app/controllers/fliip_services_controller.rb
class FliipServicesController < ApplicationController
  before_action :authenticate_user!

  def show
    @service = FliipService
                 .includes(:fliip_user, :service_definition)
                 .find(params[:id])

    # All sessions for this service (confirmed + unconfirmed; present + absent)
    scope = @service.sessions
                     .includes(:fliip_user, :fliip_service)
                     .order(Arel.sql("COALESCE(date, '0001-01-01') DESC"),
                            Arel.sql("COALESCE(time, '00:00:00') DESC"),
                            created_at: :desc)

    @pagy, @sessions = pagy(scope, items: 50)

    # Usage aggregates (hours-as-sessions, so 0.5 is half a session)
    sums = @service.sessions.group(:session_type).sum(:duration)
    @paid_used = sums.fetch("paid", 0.0).to_f
    @free_used = sums.fetch("free", 0.0).to_f

    @paid_total = @service.service_definition&.paid_sessions
    @free_total = @service.service_definition&.free_sessions

    @status_label = {
      "A" => "Active", "I" => "Inactive", "P" => "Planned",
      "C" => "Cancelled", "S" => "Stopped"
    }[@service.purchase_status] || "-"
  end
end
