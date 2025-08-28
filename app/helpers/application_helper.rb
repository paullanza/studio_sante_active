module ApplicationHelper
  include Pagy::Frontend

  def dashboard_path_for(user)
    return admin_dashboard_path   if user.admin? || user.super_admin?
    return manager_dashboard_path if user.manager?
    user_path(user)
  end
end
