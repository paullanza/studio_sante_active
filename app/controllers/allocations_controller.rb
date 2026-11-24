# Allocations (ServiceDefinition): the séances and absences allowed for each
# kind of service. Kinds not set yet (« à définir ») wait in a queue on the
# left and are saved together; the defined ones are read-only, grouped by
# family, and change only in « Mode correction » (?corriger=1).
class AllocationsController < ApplicationController
  before_action :authenticate_user!
  layout "studio"

  def index
    authorize ServiceDefinition

    @query = params[:q].to_s.strip
    @correcting = params[:corriger] == "1"
    load_lists
  end

  def show
    @definition = ServiceDefinition.find(params[:id])
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

  # Saves every allocation sent in `allocations[ID][paid_sessions|free_sessions]`
  # in one transaction: all or nothing. A queue entry left blank stays
  # « à définir »; an unchanged allocation isn't written.
  def bulk_update
    authorize ServiceDefinition

    @query = params[:q].to_s.strip
    @correcting = params[:mode] == "correction"
    changed = changed_definitions

    if changed.empty?
      redirect_to allocations_path(index_params), notice: "Aucune modification.", status: :see_other
    elsif save_all(changed)
      redirect_to allocations_path(q: @query.presence), notice: saved_notice(changed.size), status: :see_other
    else
      @edited = changed.index_by(&:id)
      load_lists
      flash.now[:alert] = "Rien n'a été enregistré : corrigez les valeurs en rouge."
      render :index, status: :unprocessable_entity
    end
  end

  private

  # The submitted allocations with their new values assigned, keeping only
  # those that change. Unknown ids are ignored.
  def changed_definitions
    submitted = params.fetch(:allocations, {})
    return [] unless submitted.respond_to?(:each_pair)

    attributes = policy(ServiceDefinition).permitted_attributes
    definitions = ServiceDefinition.where(id: submitted.keys).index_by { |d| d.id.to_s }

    submitted.each_pair.filter_map do |id, values|
      definition = definitions[id]
      next unless definition && values.respond_to?(:permit)

      values = values.permit(*attributes)
      # An untouched queue entry stays « à définir ».
      next if definition.to_define? && attributes.all? { |attr| values[attr].blank? }

      definition.assign_attributes(values)
      definition if definition.changed?
    end
  end

  def save_all(definitions)
    valid = definitions.map(&:valid?).all?
    return false unless valid

    ServiceDefinition.transaction { definitions.each(&:save!) }
    true
  end

  def saved_notice(count)
    noun = @correcting ? "correction" : "allocation"
    "#{count} #{noun.pluralize(count)} #{count > 1 ? 'enregistrées' : 'enregistrée'}."
  end

  def index_params
    { q: @query.presence, corriger: (1 if @correcting) }.compact
  end

  # The queue and the families, filtered by @query, with each kind's active
  # services counted in one query. After a failed save, the records with
  # errors (@edited) take the place of the fresh ones.
  def load_lists
    definitions = ServiceDefinition.matching(@query).order(:service_name, :service_id).to_a
    definitions.map! { |d| @edited&.fetch(d.id, nil) || d }

    # By the saved values, so a queue entry that failed to save stays in the queue.
    @to_define, defined = definitions.partition(&:to_define_in_database?)
    @families = defined.group_by(&:family).sort_by { |family, _| ServiceDefinition::FAMILY_ORDER.index(family) || 99 }
    @defined_count = defined.size
    @active_counts = FliipService.active.where(service_id: definitions.map(&:service_id)).group(:service_id).count
  end
end
