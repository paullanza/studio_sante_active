# app/models/session.rb
class Session < ApplicationRecord
  belongs_to :user
  belongs_to :fliip_user
  belongs_to :fliip_service

  # ---------- Validations ----------
  validates :fliip_user_id, :fliip_service_id, :date, :time, presence: true

  validates :fliip_user_id, uniqueness: {
    scope: [:fliip_service_id, :date, :time],
    message: "already has a session at this time with this service"
  }

  # Service active relative to the *session date*
  validate :service_is_active, on: :create
  # Booking window relative to *today* (± 1 month rule)
  validate :within_booking_window, on: :create
  # Enforce quotas using FliipService (includes adjustments & bonus)
  validate :respect_quota_limits, on: :create

  # ---------- Callbacks ----------
  before_validation :set_session_type_and_duration, on: :create

  # ---------- Scopes ----------
  scope :unconfirmed, -> { where(confirmed: false) }
  scope :confirmed,   -> { where(confirmed: true) }

  # ---------- Display ----------
  def duration_display
    case duration
    when 1.0 then "1 hour"
    when 0.5 then "30 minutes"
    else          "#{duration.to_f} h"
    end
  end

  private

  # Decide type (free/paid) using presence + available quotas from FliipService.
  # - Present sessions are always paid.
  # - Absent sessions try to consume free quota first; otherwise paid.
  def set_session_type_and_duration
    self.duration = (duration.presence || 1.0).to_f

    if present
      self.session_type = "paid"
      return
    end

    # If there is no definition, default to paid (can't evaluate free allowance safely)
    if fliip_service.service_definition.nil?
      self.session_type = "paid"
      return
    end

    free_remaining = fliip_service.remaining_free_sessions.to_f
    self.session_type = (free_remaining >= duration) ? "free" : "paid"
  end

  # Prevent creating a session that would exceed *paid* quota.
  # Uses FliipService totals so adjustments & bonus are included.
  def respect_quota_limits
    return if fliip_service.service_definition.nil? # if no definition, skip quota enforcement

    if session_type == "paid"
      remaining = fliip_service.remaining_paid_sessions.to_f
      if remaining < duration.to_f
        errors.add(:base, "No paid sessions remaining for this service.")
      end
    elsif session_type == "free"
      remaining = fliip_service.remaining_free_sessions.to_f
      if remaining < duration.to_f
        errors.add(:base, "No free sessions remaining for this service.")
      end
    end
  end

  # Keep your existing "service active relative to session date" rule
  def service_is_active
    return if date.blank?

    if fliip_service.expire_date.present? && date > fliip_service.expire_date
      errors.add(:base, "The service has ended.")
    end

    if fliip_service.start_date.present? && date < fliip_service.start_date
      errors.add(:base, "The service has not started.")
    end
  end

  # Additional guard: block booking if service is too far in past/future relative to today
  def within_booking_window
    today        = Date.current
    future_limit = today.next_month
    past_limit   = today.last_month

    starts_too_late = fliip_service.start_date.present?  && fliip_service.start_date  > future_limit
    ended_too_long  = fliip_service.expire_date.present? && fliip_service.expire_date < past_limit

    if starts_too_late || ended_too_long
      errors.add(:base, "This service can’t be booked (outside allowed dates).")
    end
  end
end
