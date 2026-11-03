# frozen_string_literal: true

# Headless policy for AdminController (authorize :admin). One method per
# action, all admin and super admin only.
class AdminPolicy < ApplicationPolicy
  def dashboard?
    admin_or_above?
  end

  def services?
    admin_or_above?
  end

  def service_show?
    admin_or_above?
  end

  def update_service?
    admin_or_above?
  end

  def client_services?
    admin_or_above?
  end

  # Mission Control at /jobs.
  def jobs?
    admin_or_above?
  end

  def import_clients?
    admin_or_above?
  end

  def create_signup_code?
    admin_or_above?
  end

  def deactivate_signup_code?
    admin_or_above?
  end

  def unconfirmed_sessions?
    admin_or_above?
  end

  def confirm_sessions?
    admin_or_above?
  end

  def unconfirmed_consultations?
    admin_or_above?
  end

  def confirm_consultations?
    admin_or_above?
  end

  def adjustments_new?
    admin_or_above?
  end

  def adjustments_preview?
    admin_or_above?
  end

  def adjustments_commit?
    admin_or_above?
  end
end
