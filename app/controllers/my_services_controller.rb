# Mes services: the services the signed-in staff member works on (a séance or
# an adjustment attributed to them): running services soonest-ending first,
# then ended ones, most recent first.
class MyServicesController < ApplicationController
  before_action :authenticate_user!
  layout "studio"

  # Active, planned and suspended by default; the toggles add inactive and cancelled.
  DEFAULT_STATUSES = %w[A P S].freeze

  def index
    authorize :my_services, :index?

    @show_inactive  = params[:inactifs] == "1"
    @show_cancelled = params[:annules] == "1"

    statuses = DEFAULT_STATUSES.dup
    statuses << "I" if @show_inactive
    statuses << "C" if @show_cancelled

    # The cards' usage totals come from .preload_usage: two queries for the list.
    @services = FliipService.worked_on_by(current_user)
                            .by_statuses(statuses)
                            .includes(:fliip_user, :service_definition)
                            .ending_soonest_first
                            .to_a
    FliipService.preload_usage(@services)
  end
end
