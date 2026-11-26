# frozen_string_literal: true

# Headless policy for AdminController (authorize :admin). One method per
# action, all admin and super admin only.
class AdminPolicy < ApplicationPolicy
  def dashboard?
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

  # Confirmations, séances tab (ConfirmationsController).
  def session_confirmations?
    admin_or_above?
  end

  def confirm_sessions?
    admin_or_above?
  end

  # Confirmations, consultations tab (ConfirmationsController).
  def consultation_confirmations?
    admin_or_above?
  end

  def confirm_consultations?
    admin_or_above?
  end
end
