# Mes services: the services the signed-in staff member works on (a séance or
# an adjustment attributed to them), soonest end date first.
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

    # Usage totals are summed in SQL, so séances and adjustments aren't preloaded.
    @services = FliipService.worked_on_by(current_user)
                            .by_statuses(statuses)
                            .includes(:fliip_user, :service_definition)
                            .order(Arel.sql("expire_date ASC NULLS LAST"))
  end
end
