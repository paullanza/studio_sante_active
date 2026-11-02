# frozen_string_literal: true

# Sessions are the record of trainer work. Everyone logs their own; admins
# manage all of them, confirmed or not.
class SessionPolicy < ApplicationPolicy
  BASE_ATTRIBUTES = [:fliip_user_id, :fliip_service_id, :present, :note].freeze

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

  def services_table?
    user.present?
  end

  def service_select?
    user.present?
  end

  def preview_type?
    user.present?
  end

  # Pulls new clients from the Fliip API, for when a client is missing from
  # the booking form.
  def refresh_clients?
    user.present?
  end

  # Choosing or changing the trainer (user_id).
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
