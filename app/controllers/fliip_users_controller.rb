class FliipUsersController < ApplicationController
  before_action :authenticate_user!
  layout "studio"

  CLIENT_TABS = %w[services contracts consultations].freeze
  # Client page order: active, planned, suspended, inactive, cancelled.
  SERVICE_STATUS_ORDER = %w[A P S I C].freeze

  def index
    authorize FliipUser

    @query = params[:query].to_s.strip
    @recent_services_by_user_id = {}

    scope = @query.present? ? FliipUser.search(@query) : FliipUser.order(:remote_id)
    @pagy, @fliip_users = pagy(
      # Adjustments aren't preloaded: the usage totals sum them in SQL.
      scope.includes(:fliip_contracts, fliip_services: :service_definition)
    )

    @fliip_users.each do |u|
      item = u.main_index_item
      @recent_services_by_user_id[u.id] = item if item
    end
  end

  def show
    # Usage totals are summed in SQL, so séances and adjustments aren't preloaded.
    @fliip_user = FliipUser.includes(:fliip_contracts, :fliip_services).find(params[:id])
    authorize @fliip_user

    @tab = CLIENT_TABS.include?(params[:tab]) ? params[:tab] : "services"
    @services = @fliip_user.fliip_services.sort_by do |s|
      [ SERVICE_STATUS_ORDER.index(s.purchase_status) || SERVICE_STATUS_ORDER.size, -(s.expire_date || Date.new(0)).jd ]
    end
    # Allocations only where the page reads them: every card on the services
    # tab, else the active services the top card counts.
    allocation_readers = @tab == "services" ? @services : @services.select { |s| s.purchase_status == "A" && !s.removed_from_fliip? }
    ActiveRecord::Associations::Preloader.new(records: allocation_readers, associations: :service_definition).call
    @contracts = @fliip_user.fliip_contracts.sort_by { |c| [ c.end_date ? 1 : 0, -(c.end_date&.jd || 0) ] }
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

    @query = params[:query].to_s.strip
    @users = FliipUser.search(@query)
               .select(:id, :user_firstname, :user_lastname, :remote_id, :user_email, :user_phone1)
               .order(:user_lastname).limit(20)

    if params[:list_only].present?
      render partial: "fliip_users/suggest_list", layout: false
    else
      render :suggest, layout: false
    end
  end
end
