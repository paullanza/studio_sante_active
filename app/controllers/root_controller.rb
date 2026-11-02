class RootController < ApplicationController
  # Only routes the signed-in user to their home page by role; there is
  # nothing to authorize.
  def redirect
    skip_authorization

    if current_user.super_admin? || current_user.admin?
      redirect_to admin_dashboard_path
    elsif current_user.manager?
      redirect_to manager_dashboard_path
    else
      redirect_to user_path(current_user) # employees → profile
    end
  end
end
