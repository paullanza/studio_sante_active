# frozen_string_literal: true

# Staff accounts. Only the super admin sees or touches the super admin.
class UserPolicy < ApplicationPolicy
  PROFILE_ATTRIBUTES = [:first_name, :last_name, :phone, :address, :birthday].freeze

  # « Personnel »: managers and above.
  def index?
    manager_or_above?
  end

  # Managers and admins see everyone but the super admin (admins have
  # clients too); the super admin sees everyone; employees see themselves.
  def show?
    super_admin? || ((admin? || manager?) && !record.super_admin?) || self?
  end

  def update?
    super_admin? || (admin? && !record.super_admin?) || self?
  end

  # The roles the viewer may give the record, its current one left out.
  # Nobody changes the super admin's role or their own. The super admin
  # gives any role but super admin; an admin switches employees and
  # managers between the two.
  def assignable_roles
    return [] if user.nil? || self? || record.super_admin?

    roles = if super_admin?
      %w[employee manager admin]
    elsif admin? && (record.employee? || record.manager?)
      %w[employee manager]
    else
      []
    end
    roles - [ record.role ]
  end

  def update_role?
    assignable_roles.any?
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

  # Nobody changes their own active status.
  def active_status_change?
    return false if self?

    super_admin? ||
      (admin? && (record.manager? || record.employee?)) ||
      (manager? && record.employee?)
  end
end
