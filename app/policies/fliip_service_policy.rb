# frozen_string_literal: true

class FliipServicePolicy < ApplicationPolicy
  def show?
    user.present?
  end
end
