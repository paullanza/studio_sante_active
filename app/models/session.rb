class Session < ApplicationRecord
  # -----------------------------------------
  # Associations
  # -----------------------------------------
  # The staff member who created or is responsible for the session.
  belongs_to :user

  # The client (from Fliip) who is attending the session.
  belongs_to :fliip_user

  # The specific purchased service (from Fliip) that this session uses.
  belongs_to :fliip_service

  # -----------------------------------------
  # Validations
  # -----------------------------------------

  # Duration must be a positive number if present (e.g., 0.5 for 30 min, 1.0 for 1 hour).
  validates :duration, numericality: { greater_than: 0 }, allow_nil: true

  # These fields must always be provided when creating a session.
  validates :fliip_user_id, :fliip_service_id, :date, :time, presence: true

  # Prevents duplicate bookings:
  #   - Same client (fliip_user_id)
  #   - Same service (fliip_service_id)
  #   - Same date and time
  validates :fliip_user_id, uniqueness: {
    scope: [:fliip_service_id, :date, :time],
    message: "already has a session at this time with this service"
  }

  # Custom validations (only on create):
  # - Checks that the service is active for the date of the session
  validate :service_is_active, on: :create
  # - Checks that the booking is within ± 1 month of today
  validate :within_booking_window, on: :create
  # - Checks that booking the session does not exceed paid/free quotas
  validate :respect_quota_limits, on: :create

  # Ensures that the chosen service actually belongs to the selected client.
  validate :service_matches_client

  # -----------------------------------------
  # Callbacks
  # -----------------------------------------
  # Before validation on create:
  #   - Determine whether this session is "free" or "paid"
  #   - Set default duration if not provided
  before_validation :set_session_type_and_duration, on: :create

  # -----------------------------------------
  # Scopes
  # -----------------------------------------
  # Sessions awaiting confirmation (false or nil).
  scope :unconfirmed, -> { where(confirmed: [false, nil]) }
  # Sessions that have been confirmed.
  scope :confirmed,   -> { where(confirmed: true) }

  # -----------------------------------------
  # Display Helpers
  # -----------------------------------------
  # Returns a human-friendly display for the duration:
  #   - "1 hour" for 1.0
  #   - "30 minutes" for 0.5
  #   - "<value> h" for other values
  def duration_display
    case duration
    when 1.0 then "1 hour"
    when 0.5 then "30 minutes"
    else          "#{duration.to_f} h"
    end
  end

  private

  # -----------------------------------------
  # Callback Helpers
  # -----------------------------------------
  # Determines the session type ("free" or "paid") and sets duration.
  #
  # Rules:
  # - Default duration is 1.0 hour unless provided.
  # - If present is true → always "paid".
  # - If no service definition exists → default to "paid" (can't evaluate free allowance).
  # - Otherwise:
  #     Use "free" if enough free sessions remain for the full duration.
  #     Otherwise, "paid".
  def set_session_type_and_duration
    self.duration = (duration.presence || 1.0).to_f

    return if fliip_service_id.blank? || fliip_service.nil?

    if present
      self.session_type = "paid"
      return
    end

    if fliip_service.service_definition.nil?
      self.session_type = "paid"
      return
    end

    free_remaining = fliip_service.remaining_free_sessions.to_f
    self.session_type = free_remaining >= duration ? "free" : "paid"
  end

  # -----------------------------------------
  # Validation Helpers
  # -----------------------------------------

  # Prevent booking if quotas would be exceeded.
  # Uses FliipService's quota calculations (which include bonuses and adjustments).
  def respect_quota_limits
    return if fliip_service.blank?
    return if fliip_service.service_definition.nil?

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

  # Checks that the service is active on the chosen session date.
  def service_is_active
    return if fliip_service.blank? || date.blank?

    if fliip_service.expire_date.present? && date > fliip_service.expire_date
      errors.add(:base, "The service has ended.")
    end

    if fliip_service.start_date.present? && date < fliip_service.start_date
      errors.add(:base, "The service has not started.")
    end
  end

  # Prevent booking outside the allowed ± 1 month window relative to today.
  def within_booking_window
    return if fliip_service.blank?
    today        = Date.current
    future_limit = today.next_month
    past_limit   = today.last_month

    starts_too_late = fliip_service.start_date.present?  && fliip_service.start_date  > future_limit
    ended_too_long  = fliip_service.expire_date.present? && fliip_service.expire_date < past_limit

    if starts_too_late || ended_too_long
      errors.add(:base, "This service can’t be booked (outside allowed dates).")
    end
  end

  # Ensures the chosen service belongs to the selected client.
  def service_matches_client
    return if fliip_service.blank? || fliip_user_id.blank?
    if fliip_service.fliip_user_id != fliip_user_id
      errors.add(:fliip_service_id, "does not belong to the selected client")
    end
  end
end
