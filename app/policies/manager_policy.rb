# frozen_string_literal: true

# Headless policy for ManagerController (authorize :manager). Managers
# only: admins and super admins use the admin dashboard instead.
class ManagerPolicy < ApplicationPolicy
  def dashboard?
    manager?
  end

  def services?
    manager?
  end

  def service_show?
    manager?
  end

  def create_signup_code?
    manager?
  end
end
