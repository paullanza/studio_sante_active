class FliipServicesController < ApplicationController
  before_action :authenticate_user!

  STATUS_LABELS = {
    "A" => "Active",
    "I" => "Inactive",
    "P" => "Planned",
    "C" => "Cancelled",
    "S" => "Stopped"
  }.freeze

  def show
    @service = FliipService
                 .includes(:fliip_user, :service_definition)
                 .find(params[:id])

    # All sessions for this service (confirmed + unconfirmed; present + absent)
    # Use explicit ::date / ::time casts for Postgres in COALESCE.
    scope = @service.sessions
                     .includes(:fliip_user) # helpful for table rendering
                     .order(Arel.sql("COALESCE(date, '0001-01-01'::date) DESC"),
                            Arel.sql("COALESCE(time, '00:00:00'::time) DESC"),
                            created_at: :desc)

    @pagy, @sessions = pagy(scope, items: 50)

    # Usage aggregates (hours-as-sessions, so 0.5 is half a session)
    sums        = @service.sessions.group(:session_type).sum(:duration)
    @paid_used  = sums.fetch("paid", 0.0).to_f
    @free_used  = sums.fetch("free", 0.0).to_f

    @paid_total = @service.service_definition&.paid_sessions
    @free_total = @service.service_definition&.free_sessions

    @status_label = STATUS_LABELS.fetch(@service.purchase_status, "-")
  end
end
