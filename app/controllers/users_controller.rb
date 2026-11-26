# « Personnel » (managers and above): the staff list, and a page per staff
# member with their details, their activity per pay period and the services
# they work on. Every role reaches their own page, whose « Accès » section
# changes the role and the active status. The profile edit keeps its old
# page until rebuilt.
class UsersController < ApplicationController
  before_action :authenticate_user!
  before_action :set_user, only: [:show, :edit, :update, :role, :activate, :deactivate]
  layout "studio", only: [:index, :show]

  STATUSES = %w[actifs inactifs tous].freeze
  TABS = %w[activite services].freeze
  # Services tab: active, planned and suspended by default, as on Mes services.
  DEFAULT_SERVICE_STATUSES = %w[A P S].freeze

  # Two views of the same figures: « Tableau » (the renewals to follow up,
  # then one row each, with the trend) and « Fiches » (a card each).
  VIEWS = %w[tableau fiches].freeze

  def index
    authorize User

    @view = VIEWS.include?(params[:vue]) ? params[:vue] : "tableau"
    @status = STATUSES.include?(params[:statut]) ? params[:statut] : "actifs"
    @role = User.roles.key?(params[:role]) ? params[:role] : nil
    @period = PayPeriod.from_param(params[:periode])
    @periods = PayPeriod.recent
    @periods << @period unless @periods.include?(@period)

    users = policy_scope(User)
    users = users.where(active: @status == "actifs") unless @status == "tous"
    users = users.where(role: @role) if @role
    @overview = StaffOverview.new(users.order(role: :desc, last_name: :asc, first_name: :asc), @period)
  end

  def show
    authorize @user

    @tab = TABS.include?(params[:tab]) ? params[:tab] : "activite"
    if @tab == "activite"
      @period = PayPeriod.from_param(params[:periode])
      @periods = PayPeriod.recent
      @periods << @period unless @periods.include?(@period)
      @activity = StaffActivity.new(@user, @period)
      FliipService.preload_usage(@activity.sessions.map(&:fliip_service))
      @follow_up = StaffOverview.new([ @user ], @period).rows.first
      @renewing = StaffOverview.renewing_services(@user).to_a
    else
      @show_inactive  = params[:inactifs] == "1"
      @show_cancelled = params[:annules] == "1"
      statuses = DEFAULT_SERVICE_STATUSES.dup
      statuses << "I" if @show_inactive
      statuses << "C" if @show_cancelled
      @services = FliipService.worked_on_by(@user).by_statuses(statuses)
                              .includes(:fliip_user, :service_definition).ending_soonest_first.to_a
      FliipService.preload_usage(@services)
    end
  end

  def edit
    authorize @user
  end

  # PATCH /users/:id
  def update
    authorize @user

    if @user.update(permitted_attributes(@user))
      redirect_to user_path(@user), notice: "User updated."
    else
      flash.now[:alert] = @user.errors.full_messages.to_sentence
      render :edit, status: :unprocessable_content
    end
  end

  # PATCH /personnel/:id/role: one of the roles the viewer may give.
  def role
    authorize @user, :update_role?

    role = params.dig(:user, :role).to_s
    unless policy(@user).assignable_roles.include?(role)
      return redirect_to user_path(@user), alert: "Ce changement de rôle n'est pas permis."
    end

    @user.update!(role: role)
    redirect_to user_path(@user), notice: "#{@user.first_name} est maintenant #{@user.translated_role.downcase}."
  end

  def activate
    authorize @user

    @user.update!(active: true)
    redirect_to user_path(@user), notice: "Compte réactivé."
  end

  # The account is signed out on its next request (ApplicationController#logout_if_inactive).
  def deactivate
    authorize @user

    @user.update!(active: false)
    redirect_to user_path(@user), notice: "Compte désactivé."
  end

  private

  def set_user
    @user = User.find(params[:id])
  end

  # Each action's own message, in French. Profiles the user cannot see fall
  # back to the default handler instead of redirecting to them.
  def user_not_authorized
    return super unless @user && policy(@user).show?

    case action_name
    when "edit", "update"
      redirect_to user_path(@user), alert: "Non autorisé·e."
    when "role"
      redirect_to user_path(@user), alert: "Vous ne pouvez pas changer le rôle de ce compte."
    when "activate"
      redirect_to user_path(@user), alert: "Vous ne pouvez pas réactiver ce compte."
    when "deactivate"
      redirect_to user_path(@user), alert: "Vous ne pouvez pas désactiver ce compte."
    else
      super
    end
  end
end
