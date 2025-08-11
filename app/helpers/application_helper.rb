module ApplicationHelper
  include Pagy::Frontend

  def dashboard_path_for(user)
    return admin_dashboard_path   if user.admin?
    return manager_dashboard_path if user.manager?
    employee_dashboard_path
  end
end
