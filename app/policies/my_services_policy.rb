# frozen_string_literal: true

# Headless policy for Mes services (authorize :my_services): every signed-in
# staff member sees the services they work on.
class MyServicesPolicy < ApplicationPolicy
  def index?
    user.present?
  end
end
