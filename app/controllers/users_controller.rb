class UsersController < ApplicationController
  before_action :authenticate_user!
  before_action :set_user, only: [:show, :update, :make_employee, :make_manager, :make_admin, :activate, :deactivate]
  before_action :authorize_role_changes!, only: [:make_employee, :make_manager, :make_admin]
  before_action :authorize_profile_update!, only: [:update]

  # GET /users/:id
  def show
    # Services this staff user has touched (sessions or adjustments)
    svc_ids_from_sessions = Session.where(user_id: @user.id).distinct.pluck(:fliip_service_id)
    svc_ids_from_adjusts  = ServiceUsageAdjustment.where(user_id: @user.id).distinct.pluck(:fliip_service_id)
    svc_ids               = (svc_ids_from_sessions + svc_ids_from_adjusts).compact.uniq

    @services_for_user = FliipService
      .where(id: svc_ids)
      .includes(:fliip_user, :service_definition, :service_usage_adjustments)
      .order(:service_name)

    @unconfirmed_sessions = Session
      .where(user_id: @user.id, confirmed: [false, nil])
      .includes(:fliip_user, :fliip_service)
      .order(date: :desc, time: :desc, created_at: :desc)
  end

  # PATCH /users/:id
  def update
    if @user.update(user_params)
      redirect_to user_path(@user), notice: "User updated."
    else
      # Rebuild show data so the page re-renders fully with errors
      show
      flash.now[:alert] = @user.errors.full_messages.to_sentence
      render :show, status: :unprocessable_entity
    end
  end

  def make_employee
    unless @user.manager?
      return redirect_back fallback_location: user_path(@user), alert: "Only managers can be demoted to employee."
    end
    @user.update!(role: :employee)
    redirect_back fallback_location: user_path(@user), notice: "#{@user.first_name} is now an Employee."
  end

  def make_manager
    if @user.employee?
      @user.update!(role: :manager)
      redirect_back fallback_location: user_path(@user), notice: "#{@user.first_name} is now a Manager."
    elsif @user.admin?
      return redirect_back fallback_location: user_path(@user), alert: "Not authorized." unless current_user.super_admin?
      @user.update!(role: :manager)
      redirect_back fallback_location: user_path(@user), notice: "#{@user.first_name} is now a Manager."
    else
      redirect_back fallback_location: user_path(@user), alert: "This change isn’t allowed."
    end
  end

  def make_admin
    unless current_user.super_admin?
      return redirect_back fallback_location: user_path(@user), alert: "Not authorized."
    end
    unless @user.manager?
      return redirect_back fallback_location: user_path(@user), alert: "Only managers can be promoted to admin."
    end
    @user.update!(role: :admin)
    redirect_back fallback_location: user_path(@user), notice: "#{@user.first_name} is now an Admin."
  end

  def activate
    if @user.active_status_change_allowed?(current_user)
      @user.activate_by!(current_user)
      redirect_back fallback_location: user_path(@user), notice: "#{@user.first_name} has been reactivated."
    else
      redirect_back fallback_location: user_path(@user), alert: "Not authorized to activate this user."
    end
  end

  def deactivate
    if @user.active_status_change_allowed?(current_user)
      @user.deactivate_by!(current_user)
      redirect_back fallback_location: user_path(@user), notice: "#{@user.first_name} has been deactivated."
    else
      redirect_back fallback_location: user_path(@user), alert: "Not authorized to deactivate this user."
    end
  end

  private

  def set_user
    @user = User.find(params[:id])
  end

  # Admins/super_admins can edit profile fields (not role/active/password)
  def authorize_profile_update!
    unless current_user.admin? || current_user.super_admin?
      redirect_to user_path(@user), alert: "Not authorized."
    end
  end

  def authorize_role_changes!
    if @user.super_admin?
      redirect_back fallback_location: user_path(@user), alert: "You can't change a Super Admin." and return
    end
    unless current_user.admin? || current_user.super_admin?
      redirect_back fallback_location: user_path(@user), alert: "Not authorized." and return
    end
  end

  def user_params
    params.require(:user).permit(
      :first_name, :last_name, :email, :phone, :address, :birthday
    )
  end
end
