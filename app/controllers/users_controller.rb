class UsersController < ApplicationController
  before_action :authenticate_user!
  before_action :set_user, only: [:show, :edit, :update, :make_employee, :make_manager, :make_admin, :activate, :deactivate]
  after_action :verify_authorized

  # GET /users/:id
  def show
    authorize @user

    # Services this staff user has touched (sessions or adjustments)
    svc_ids_from_sessions = Session.where(user_id: @user.id).distinct.pluck(:fliip_service_id)
    svc_ids_from_adjusts  = ServiceUsageAdjustment.where(user_id: @user.id).distinct.pluck(:fliip_service_id)
    svc_ids               = (svc_ids_from_sessions + svc_ids_from_adjusts).compact.uniq

    # Build visible statuses from params (defaults: A, P, S)
    statuses = %w[A P S]
    statuses << "I" if params[:show_inactive]  == "1"
    statuses << "C" if params[:show_cancelled] == "1"
    statuses -= ["S"] if params[:hide_stopped] == "1"
    statuses.uniq!

    @services_for_user = FliipService
      .where(id: svc_ids)
      .by_statuses(statuses)
      .includes(:fliip_user, :service_definition, :service_usage_adjustments)
      .order(expire_date: :asc)

    @unconfirmed_sessions = Session
      .where(user_id: @user.id, confirmed: [false, nil])
      .present_value(params[:present])
      .of_type(params[:session_type])
      .includes(:fliip_user, :fliip_service)
      .order_by_occurred_at_desc

    @consultations_for_user = Consultation
      .where(user_id: @user.id)
      .with_associations
      .order_by_occurred_at_desc

    if params[:show_confirmed] == "1"
      @consultations_for_user = @consultations_for_user.confirmed
    else
      @consultations_for_user = @consultations_for_user.unconfirmed
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
      # Rebuild show data so the page re-renders fully with errors
      show
      flash.now[:alert] = @user.errors.full_messages.to_sentence
      render :show, status: :unprocessable_content
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
