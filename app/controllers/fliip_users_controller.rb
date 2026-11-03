class FliipUsersController < ApplicationController
  before_action :authenticate_user!

  def index
    authorize FliipUser

    scope = FliipUser.order(:remote_id)
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
    authorize @fliip_user

    @consultations = @fliip_user.consultations.with_associations.order_by_occurred_at_desc
  end

  def refresh
    authorize FliipUser

    remote_id = Integer(params[:remote_id], exception: false)
    return redirect_to(fliip_users_path, alert: "Client·e introuvable dans Fliip.") unless remote_id

    result = FliipApi::UserSyncer.new(client: FliipApi::Client.new).call_by_remote_id(remote_id)
    notice = result.changed? ? "Client·e mis·e à jour depuis Fliip." : "Client·e déjà à jour."
    redirect_to fliip_user_path(result.user), notice: notice
  rescue FliipApi::NotFound
    # The syncer flagged the client (and their records) as missing from Fliip.
    user = FliipUser.find_by(remote_id: remote_id)
    target = user ? fliip_user_path(user) : fliip_users_path
    redirect_to target, alert: "Client·e introuvable dans Fliip."
  rescue FliipApi::Unavailable => e
    Rails.logger.error("[Fliip] refresh of #{remote_id} failed: #{e.message}")
    redirect_back fallback_location: fliip_users_path, alert: "Fliip ne répond pas, réessayez plus tard."
  end

  def suggest
    authorize FliipUser

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
