module ApplicationHelper
  def dashboard_path_for(user)
    return admin_dashboard_path   if user.admin? || user.super_admin?
    return manager_dashboard_path if user.manager?
    user_path(user)
  end

  # Staff for an owner dropdown, plus the record's current owner when they
  # are no longer selectable (e.g. deactivated), so saving an edit never
  # reassigns the record to whoever is listed first.
  def owner_options(staff, current_owner)
    users = staff.to_a
    users += [current_owner] if current_owner && users.exclude?(current_owner)
    users
  end

  def owner_option_label(user)
    user.active? ? user.full_name : "#{user.full_name} (inactif·ve)"
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
