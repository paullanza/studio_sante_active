# frozen_string_literal: true

# Consultations follow the session rules. Associating one with a client
# is a management task and can happen after confirmation.
class ConsultationPolicy < ApplicationPolicy
  BASE_ATTRIBUTES = [:first_name, :last_name, :email, :phone_number, :note, :present].freeze

  def create?
    user.present?
  end

  # Employees and managers: only their own, and only while unconfirmed.
  def update?
    admin_or_above? || own_unconfirmed?
  end

  def destroy?
    update?
  end

  def row?
    user.present?
  end

  # Any consultation, confirmed or not.
  def association?
    manager_or_above?
  end

  def associate?
    manager_or_above?
  end

  def service_select?
    manager_or_above?
  end

  def associations?
    manager_or_above?
  end

  def disassociate?
    admin_or_above?
  end

  # Choosing or changing the employee (user_id).
  def change_owner?
    admin_or_above?
  end

  def permitted_attributes
    change_owner? ? BASE_ATTRIBUTES + [:user_id] : BASE_ATTRIBUTES
  end

  private

  def own_unconfirmed?
    user.present? && !record.confirmed? && record.user_id == user.id
  end
end
