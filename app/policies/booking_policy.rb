# frozen_string_literal: true

# Headless policy for the booking page (authorize :booking).
class BookingPolicy < ApplicationPolicy
  def new?
    user.present?
  end
end
