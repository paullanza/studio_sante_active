class FliipUsersController < ApplicationController
  before_action :authenticate_user!

  def index
    scope = FliipUser.order(:id)
    scope = scope.search_clients(params[:query]) if params[:query].present?

    scope = scope.includes(
      :fliip_contracts,
      fliip_services: [:service_definition, :service_usage_adjustments, :sessions]
    )

    @pagy, @fliip_users = pagy(scope)

    @recent_services_by_user_id = {}
    @fliip_users.each do |u|
      svc = u.most_recent_index_service
      if svc
        @recent_services_by_user_id[u.id] = svc
      else
        contract = u.best_active_contract_for_index
        @recent_services_by_user_id[u.id] = contract if contract
      end
    end
  end

  def show
    @fliip_user = FliipUser
      .includes(
        :fliip_contracts,
        fliip_services: [
          :service_definition,
          :service_usage_adjustments,
          :sessions,
          :consultation
        ]
      )
      .find(params[:id])
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

    if params[:list_only].present?
      render partial: "fliip_users/suggest_list", layout: false
    else
      render :suggest, layout: false
    end
  end
end
