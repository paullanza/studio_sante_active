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

  # Service dates sanity (based on session date)
  validate :service_is_active, on: :create
  # Booking window (based on *today* vs service start/end)
  validate :within_booking_window, on: :create
  # Enforce quotas after we decide the type
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
    else
      "#{duration.to_f} h"
    end
  end

  # ---------- Quota helpers ----------
  def paid_quota_total
    fliip_service.service_definition&.paid_sessions.to_f
  end

  def free_quota_total
    fliip_service.service_definition&.free_sessions.to_f
  end

  def paid_used_sum
    Session.where(fliip_service_id: fliip_service_id, session_type: "paid").sum(:duration).to_f
  end

  def free_used_sum
    Session.where(fliip_service_id: fliip_service_id, session_type: "free").sum(:duration).to_f
  end

  def paid_remaining
    [paid_quota_total - paid_used_sum, 0.0].max
  end

  def free_remaining
    [free_quota_total - free_used_sum, 0.0].max
  end

  private

  # Decide type (free/paid) using presence + quotas.
  # - Present sessions are always paid.
  # - Absent sessions try to consume free quota; if not enough, they become paid.
  def set_session_type_and_duration
    # Default duration safety net (controller sets it explicitly)
    self.duration = (duration.presence || 1.0).to_f

    if present
      self.session_type = "paid"
    else
      # Try to use free quota first
      if free_remaining >= duration
        self.session_type = "free"
      else
        self.session_type = "paid"
      end
    end
  end

  # Prevent creating a session that would exceed *paid* quota.
  # (Business rule you asked for.)
  def respect_quota_limits
    # If there is no definition, we can't evaluate quotas.
    return if fliip_service.service_definition.nil?

    if session_type == "paid" && paid_remaining < duration.to_f
      errors.add(:base, "No paid sessions remaining for this service.")
    end
  end

  # Keep your existing "service active relative to session date" rule
  def service_is_active
    return if date.blank? # in case you ever allow null dates for bulk ops

    if fliip_service.expire_date.present? && date > fliip_service.expire_date
      errors.add(:base, "The service has ended.")
    end

    if fliip_service.start_date.present? && date < fliip_service.start_date
      errors.add(:base, "The service has not started.")
    end
  end

  # Additional guard: do not allow booking if service is too far in the past/future
  # relative to *today* (your “±1 month window” rule).
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
