# frozen_string_literal: true

# Adjustments are read by management and written by admins only.
class ServiceUsageAdjustmentPolicy < ApplicationPolicy
  # The adjustments tab on a service page; read-only for managers.
  def index?
    manager_or_above?
  end

  def create?
    admin_or_above?
  end

  def update?
    admin_or_above?
  end

  def destroy?
    admin_or_above?
  end

  # Only admins reach create and update, and they choose the employee.
  def permitted_attributes
    [:paid_used_delta, :free_used_delta, :bonus_sessions, :user_id]
  end
end
