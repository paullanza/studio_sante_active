class FliipUsersController < ApplicationController
  before_action :authenticate_user!

  def index
    scope = FliipUser.order(:id)
    scope = scope.search_clients(params[:query]) if params[:query].present?

    scope = scope.includes(
      :fliip_contracts,
      fliip_services: [
        :service_definition,
        :service_usage_adjustments,
        :sessions
      ]
    )

    @pagy, @fliip_users = pagy(scope)

    # Pick a "most recent" service per user (by expire_date, then start_date)
    @recent_services_by_user_id = {}
    @fliip_users.each do |u|
      svc = u.fliip_services.max_by do |s|
        [s.expire_date || Date.new(0), s.start_date || Date.new(0)]
      end
      @recent_services_by_user_id[u.id] = svc if svc
    end
  end

  def show
    @fliip_user = FliipUser.includes(
      fliip_services: [
        :service_definition,
        :service_usage_adjustments,
        :sessions
      ]
    ).find(params[:id])
  end

  def refresh
    remote_id = params[:remote_id]
    msg = FliipApi::UserSync::UserUpdater.call(remote_id.to_i)
    redirect_to fliip_user_path(FliipUser.find_by(remote_id: remote_id)), notice: msg
  end

  def suggest
    q = params[:query].to_s.strip
    @users =
      if q.length >= 2
        FliipUser.search_clients(q).select(:id, :user_firstname, :user_lastname, :remote_id).order(:user_lastname).limit(20)
      else
        FliipUser.none
      end

    render :suggest, layout: false
  end
end
