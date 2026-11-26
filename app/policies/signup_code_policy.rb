# frozen_string_literal: true

# « Codes d'inscription »: managers and above create codes for new hires and
# deactivate them.
class SignupCodePolicy < ApplicationPolicy
  def index?
    manager_or_above?
  end

  def create?
    manager_or_above?
  end

  # Only a code that could still be used.
  def deactivate?
    manager_or_above? && record.usable?
  end
end
