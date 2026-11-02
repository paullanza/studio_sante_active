# frozen_string_literal: true

# Staff accounts. Only the super admin sees or touches the super admin.
class UserPolicy < ApplicationPolicy
  PROFILE_ATTRIBUTES = [:first_name, :last_name, :phone, :address, :birthday].freeze

  def show?
    super_admin? || ((admin? || manager?) && !record.super_admin?) || self?
  end

  def update?
    super_admin? || (admin? && !record.super_admin?) || self?
  end

  # The target's current role is checked in each action, which keeps its
  # own message for a target that does not fit.
  def make_employee?
    role_change?
  end

  # role_change? already limits an admin target to the super admin.
  def make_manager?
    role_change?
  end

  def make_admin?
    super_admin? && role_change?
  end

  def activate?
    active_status_change?
  end

  def deactivate?
    active_status_change?
  end

  # Email only on your own profile. Passwords never go through here.
  def permitted_attributes
    self? ? PROFILE_ATTRIBUTES + [:email] : PROFILE_ATTRIBUTES
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      if super_admin?
        scope.all
      elsif admin? || manager?
        scope.where.not(role: :super_admin)
      elsif user
        scope.where(id: user.id)
      else
        scope.none
      end
    end
  end

  private

  def self?
    user.present? && user == record
  end

  # Nobody changes the super admin's role, and an admin changes neither
  # their own role nor another admin's.
  def role_change?
    return false if record.super_admin?

    super_admin? || (admin? && !record.admin?)
  end

  # Nobody changes their own active status.
  def active_status_change?
    return false if self?

    super_admin? ||
      (admin? && (record.manager? || record.employee?)) ||
      (manager? && record.employee?)
  end
end
