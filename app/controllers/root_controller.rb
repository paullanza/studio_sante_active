class RootController < ApplicationController
  def redirect
    if current_user.super_admin? || current_user.admin?
      redirect_to admin_dashboard_path
    elsif current_user.manager?
      redirect_to manager_dashboard_path
    else
      redirect_to user_path(current_user) # employees → profile
    end
  end
end
