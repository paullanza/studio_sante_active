class FliipUsersController < ApplicationController
  before_action :authenticate_user!

  def index
    scope = FliipUser.order(:id)
    scope = scope.search_clients(params[:query]) if params[:query].present?

    # Eager load to avoid N+1 when rendering counts/definitions
    scope = scope.includes(:fliip_contracts, fliip_services: [:service_definition])

    @pagy, @fliip_users = pagy(scope)

    # Pick a "most recent" service per user (by expire_date, then start_date)
    @recent_services_by_user_id = {}
    @fliip_users.each do |u|
      svc = u.fliip_services.max_by do |s|
        [s.expire_date || Date.new(0), s.start_date || Date.new(0)]
      end
      @recent_services_by_user_id[u.id] = svc if svc
    end

    recent_service_ids = @recent_services_by_user_id.values.compact.map(&:id)

    # Precompute usage sums only for those recent services (paid/free durations)
    @usage_sums =
      if recent_service_ids.any?
        Session.where(fliip_service_id: recent_service_ids)
              .group(:fliip_service_id, :session_type)
              .sum(:duration)
      else
        {}
      end
  end

  def show
    @fliip_user = FliipUser.find(params[:id])

    service_ids = @fliip_user.fliip_services.map(&:id)

    @usage_sums = Session
      .where(fliip_service_id: service_ids)
      .group(:fliip_service_id, :session_type)
      .sum(:duration)
  end

  def refresh
    remote_id = params[:remote_id]
    FliipApi::UserSync::UserUpdater.call(remote_id.to_i)
    redirect_to fliip_user_path(FliipUser.find_by(remote_id: remote_id)), notice: "User data refreshed."
  end
end
