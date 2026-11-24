# frozen_string_literal: true

# Headless policy for OversightController (authorize :oversight): the
# « Plus » pages managers and above use to follow up on clients and staff.
class OversightPolicy < ApplicationPolicy
  def echeances?
    manager_or_above?
  end

  def recent_sessions?
    manager_or_above?
  end
end
