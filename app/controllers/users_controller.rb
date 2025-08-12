class UsersController < ApplicationController
  before_action :authenticate_user!
  before_action :set_user, only: [:show, :make_employee, :make_manager, :make_admin, :activate, :deactivate]
  before_action :authorize_role_changes!, only: [:make_employee, :make_manager, :make_admin]

  def show
    @clients = FliipUser.joins(:sessions)
                              .where(sessions: { user_id: @user.id })
                              .distinct
                              .order(:user_lastname, :user_firstname)
  end

  def make_employee
    # Allowed: admin or super_admin, target must be manager
    unless @user.manager?
      return redirect_back fallback_location: user_path(@user), alert: "Only managers can be demoted to employee."
    end

    @user.update!(role: :employee)
    redirect_back fallback_location: user_path(@user), notice: "#{@user.first_name} is now an Employee."
  end

  def make_manager
    # Allowed:
    # - admin or super_admin can promote employee -> manager
    # - super_admin can demote admin -> manager
    if @user.employee?
      # ok for admin/super_admin
      @user.update!(role: :manager)
      redirect_back fallback_location: user_path(@user), notice: "#{@user.first_name} is now a Manager."
    elsif @user.admin?
      # only super_admin may demote admin -> manager
      return redirect_back fallback_location: user_path(@user), alert: "Not authorized." unless current_user.super_admin?
      @user.update!(role: :manager)
      redirect_back fallback_location: user_path(@user), notice: "#{@user.first_name} is now a Manager."
    else
      redirect_back fallback_location: user_path(@user), alert: "This change isn’t allowed."
    end
  end

  def make_admin
    # Allowed: super_admin only, target must be manager
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


  def authorize_role_changes!
    # Nobody can change a super_admin
    if @user.super_admin?
      redirect_back fallback_location: user_path(@user), alert: "You can't change a Super Admin." and return
    end

    # Only admins or super_admins can change roles at all
    unless current_user.admin? || current_user.super_admin?
      redirect_back fallback_location: user_path(@user), alert: "Not authorized." and return
    end
  end
end
