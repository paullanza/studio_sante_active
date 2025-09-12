module ApplicationHelper
  include Pagy::Frontend

  def dashboard_path_for(user)
    return admin_dashboard_path   if user.admin? || user.super_admin?
    return manager_dashboard_path if user.manager?
    user_path(user)
  end

  def flash_toast_bg(type)
    case type.to_sym
    when :notice, :success
      "text-bg-success"
    when :alert, :error, :danger
      "text-bg-danger"
    when :warning
      "text-bg-warning"
    when :info
      "text-bg-info"
    else
      "text-bg-info"
    end
  end
end
