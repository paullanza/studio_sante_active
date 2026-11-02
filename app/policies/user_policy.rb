# frozen_string_literal: true

class UserPolicy < ApplicationPolicy
  # Only the super admin sees the super admin. Employees see only themselves.
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
end
