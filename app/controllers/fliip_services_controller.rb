class FliipServicesController < ApplicationController
  before_action :authenticate_user!
  layout "studio"

  SERVICE_TABS = %w[sessions consultations adjustments].freeze

  def show
    # Usage totals are summed in SQL. The tab counts need the adjustments and
    # the consultation; the staff on each list are preloaded for the open tab only.
    @service = FliipService
                 .includes(:fliip_user, :service_definition, :service_usage_adjustments, :consultation)
                 .find(params[:id])
    authorize @service

    adjustments_visible = policy(ServiceUsageAdjustment).index?
    @tab = SERVICE_TABS.include?(params[:tab]) ? params[:tab] : "sessions"
    @tab = "sessions" if @tab == "adjustments" && !adjustments_visible

    @numbered_sessions = @service.numbered_sessions
    # One linked consultation today (has_one); a list so it can become has_many.
    @consultations = Array(@service.consultation)
    @adjustments = adjustments_visible ? @service.service_usage_adjustments.sort_by(&:created_at).reverse : []

    case @tab
    when "sessions" then preload_staff(@numbered_sessions.map(&:first))
    when "consultations" then preload_staff(@consultations)
    when "adjustments" then preload(@adjustments, :user)
    end

    # Built after @adjustments so the unsaved record isn't listed.
    can_create = policy(ServiceUsageAdjustment).create?
    @adjustment = can_create ? @service.service_usage_adjustments.new(user: current_user) : nil
    @staff = can_create ? User.selectable.order(:first_name, :last_name) : []
  end

  private

  # The trainer, and the creator only where the card shows « Saisie par ».
  def preload_staff(records)
    preload(records, :user)
    preload(records.reject { |r| r.created_by_id == r.user_id }, :created_by)
  end

  def preload(records, associations)
    ActiveRecord::Associations::Preloader.new(records: records, associations: associations).call
  end
end
