class UsersController < ApplicationController
  before_action :authenticate_user!
  before_action :set_user, only: [:show, :toggle_role, :activate, :deactivate]

  def show
    # Pundit-style authorization to be added later
  end

  def toggle_role
    unless current_user.admin?
      redirect_back fallback_location: user_path(@user), alert: "Not authorized."
      return
    end

    if @user.admin?
      redirect_back fallback_location: user_path(@user), alert: "You can't change an admin's role."
      return
    end

    new_role = @user.employee? ? :manager : :employee
    @user.update!(role: new_role)

    redirect_back fallback_location: user_path(@user), notice: "#{@user.first_name} is now a #{new_role.to_s.humanize}."
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
end
