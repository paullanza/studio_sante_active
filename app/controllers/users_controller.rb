# « Personnel » (managers and above): the staff list, and a page per staff
# member with their details, their activity per pay period and the services
# they work on. Every role reaches their own page. The member routes below
# (role, active status, profile edit) keep their old pages until rebuilt.
class UsersController < ApplicationController
  before_action :authenticate_user!
  before_action :set_user, only: [:show, :edit, :update, :make_employee, :make_manager, :make_admin, :activate, :deactivate]
  layout "studio", only: [:index, :show]

  STATUSES = %w[actifs inactifs tous].freeze
  TABS = %w[activite services].freeze
  # Services tab: active, planned and suspended by default, as on Mes services.
  DEFAULT_SERVICE_STATUSES = %w[A P S].freeze

  def index
    authorize User

    @status = STATUSES.include?(params[:statut]) ? params[:statut] : "actifs"
    @role = User.roles.key?(params[:role]) ? params[:role] : nil

    users = policy_scope(User)
    users = users.where(active: @status == "actifs") unless @status == "tous"
    users = users.where(role: @role) if @role
    @users = users.order(role: :desc, last_name: :asc, first_name: :asc).to_a

    ids = @users.map(&:id)
    @unconfirmed_sessions = Session.unconfirmed.where(user_id: ids).group(:user_id).count
    @unconfirmed_consultations = Consultation.unconfirmed.where(user_id: ids).group(:user_id).count
    @services_worked_on = services_worked_on(ids)
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

  def make_employee
    authorize @user

    unless @user.manager?
      return redirect_back fallback_location: user_path(@user), alert: "Only managers can be demoted to employee."
    end
    @user.update!(role: :employee)
    redirect_back fallback_location: user_path(@user), notice: "#{@user.first_name} is now an Employee."
  end

  def make_manager
    authorize @user

    if @user.employee? || @user.admin?
      @user.update!(role: :manager)
      redirect_back fallback_location: user_path(@user), notice: "#{@user.first_name} is now a Manager."
    else
      redirect_back fallback_location: user_path(@user), alert: "This change isn’t allowed."
    end
  end

  def make_admin
    authorize @user

    unless @user.manager?
      return redirect_back fallback_location: user_path(@user), alert: "Only managers can be promoted to admin."
    end
    @user.update!(role: :admin)
    redirect_back fallback_location: user_path(@user), notice: "#{@user.first_name} is now an Admin."
  end

  def activate
    authorize @user

    @user.update!(active: true)
    redirect_back fallback_location: user_path(@user), notice: "#{@user.first_name} has been reactivated."
  end

  def deactivate
    authorize @user

    @user.update!(active: false)
    redirect_back fallback_location: user_path(@user), notice: "#{@user.first_name} has been deactivated."
  end

  private

  # Services worked on per staff member: a séance or an adjustment attributed
  # to them, each service counted once. Two queries, then Ruby.
  def services_worked_on(ids)
    pairs = Session.where(user_id: ids).distinct.pluck(:user_id, :fliip_service_id) +
            ServiceUsageAdjustment.where(user_id: ids).distinct.pluck(:user_id, :fliip_service_id)
    pairs.uniq.group_by(&:first).transform_values(&:size)
  end

  def set_user
    @user = User.find(params[:id])
  end

  # Keeps each action's existing message. Profiles the user cannot see fall
  # back to the default handler instead of redirecting to them.
  def user_not_authorized
    return super unless @user && policy(@user).show?

    case action_name
    when "edit", "update"
      redirect_to user_path(@user), alert: "Not authorized."
    when "make_employee", "make_manager", "make_admin"
      alert = @user.super_admin? ? "You can't change a Super Admin." : "Not authorized."
      redirect_back fallback_location: user_path(@user), alert: alert
    when "activate"
      redirect_back fallback_location: user_path(@user), alert: "Not authorized to activate this user."
    when "deactivate"
      redirect_back fallback_location: user_path(@user), alert: "Not authorized to deactivate this user."
    else
      super
    end
  end
end
