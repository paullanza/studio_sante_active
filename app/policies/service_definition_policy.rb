# frozen_string_literal: true

# Allocations (ServiceDefinition): the séances and absences allowed for each
# kind of service. Admins and the super admin only.
class ServiceDefinitionPolicy < ApplicationPolicy
  def index?
    admin_or_above?
  end

  def show?
    admin_or_above?
  end

  # Saves several allocations at once (the queue, or the corrections).
  def bulk_update?
    admin_or_above?
  end

  def permitted_attributes
    %i[paid_sessions free_sessions]
  end
end
