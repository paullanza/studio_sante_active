# Allocations (ServiceDefinition): the séances and absences allowed for each
# kind of service. Admins set them in place, row by row; kinds of service not
# set yet (« à définir ») come first, since their services can't be booked.
class AllocationsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_definition, only: %i[show update]
  layout "studio"

  def index
    authorize ServiceDefinition

    @query = params[:q].to_s.strip
    load_lists
  end

  def show
    authorize @definition

    services = @definition.fliip_services
    @active_count = services.active.count
    @total_count = services.count
    # Adjustments aren't preloaded: the cards' usage totals sum them in SQL.
    @pagy, @services = pagy(
      services.includes(:fliip_user, :service_definition)
              .order(Arel.sql("expire_date DESC NULLS LAST"), :id)
    )
  end

  # Turbo stream: the row is replaced in place. When the allocation leaves
  # « à définir », both sections are re-rendered so it moves down and the
  # counts follow. Other rows keep what was typed in them only when it doesn't.
  def update
    authorize @definition

    @query = params[:q].to_s.strip
    was_to_define = @definition.to_define?

    if @definition.update(permitted_attributes(@definition))
      @moved = was_to_define && !@definition.to_define?
      load_lists if @moved
      @active_count = active_counts([ @definition.service_id ]).fetch(@definition.service_id, 0)

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to allocations_path(q: @query.presence), notice: "Allocation mise à jour." }
      end
    else
      @active_count = active_counts([ @definition.service_id ]).fetch(@definition.service_id, 0)

      respond_to do |format|
        format.turbo_stream { render :update_failed, status: :unprocessable_entity }
        format.html do
          load_lists
          render :index, status: :unprocessable_entity
        end
      end
    end
  end

  private

  def set_definition
    @definition = ServiceDefinition.find(params[:id])
  end

  # Both sections of the index, filtered by @query, and each kind's active
  # services, counted in one query.
  def load_lists
    scope = ServiceDefinition.matching(@query)
    @to_define = scope.to_define.order(:service_name, :service_id).to_a
    @defined = scope.where.not(id: @to_define.map(&:id)).order(:service_name, :service_id).to_a
    @active_counts = active_counts((@to_define + @defined).map(&:service_id))
  end

  def active_counts(service_ids)
    FliipService.active.where(service_id: service_ids).group(:service_id).count
  end
end
