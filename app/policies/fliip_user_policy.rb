# frozen_string_literal: true

# Clients are mirrored from Fliip and open to every signed-in user.
class FliipUserPolicy < ApplicationPolicy
  def index?
    user.present?
  end

  def show?
    user.present?
  end

  def suggest?
    user.present?
  end

  # Pulls one client from the Fliip API. Intentionally open: staff refresh a
  # client when Fliip data is stale.
  def refresh?
    user.present?
  end
end
