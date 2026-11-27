# frozen_string_literal: true

# Headless policy for ManagerController (authorize :manager). Managers
# only: admins and super admins use the admin dashboard instead.
class ManagerPolicy < ApplicationPolicy
  def dashboard?
    manager?
  end
end
