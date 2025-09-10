class FliipService < ApplicationRecord
  # -----------------------------------------
  # Associations
  # -----------------------------------------
  # Each FliipService belongs to a specific FliipUser.
  belongs_to :fliip_user, inverse_of: :fliip_services

  # A service can have many associated session records in our app.
  # If any sessions exist, deletion of the service is prevented (validation error).
  has_many   :sessions, dependent: :restrict_with_error, inverse_of: :fliip_service

  # Links to a ServiceDefinition record (internal definition of a service type).
  # This uses a non-standard association:
  #   - primary_key: :service_id on ServiceDefinition
  #   - foreign_key: :service_id in FliipService
  # It's optional because not all services may have a definition.
  belongs_to :service_definition,
              primary_key: :service_id,
              foreign_key: :service_id,
              optional: true

  # A service can have adjustments applied to its usage (bonus sessions, corrections, etc.).
  # Adjustments are deleted if the service is deleted.
  has_many   :service_usage_adjustments, dependent: :destroy, inverse_of: :fliip_service

  # -----------------------------------------
  # Scopes: by purchase status
  # -----------------------------------------
  # These match codes returned by the Fliip API:
  #   "A" → Active
  #   "I" → Inactive
  #   "P" → Planned
  #   "C" → Cancelled
  #   "S" → Stopped
  scope :active,    -> { where(purchase_status: "A") }
  scope :inactive,  -> { where(purchase_status: "I") }
  scope :planned,   -> { where(purchase_status: "P") }
  scope :cancelled, -> { where(purchase_status: "C") }
  scope :stopped,   -> { where(purchase_status: "S") }

  # Scope: currently active services within valid date range.
  scope :current, -> {
    where(purchase_status: "A")
      .where("start_date IS NULL OR start_date <= ?", Date.current)
      .where("expire_date IS NULL OR expire_date >= ?", Date.current)
  }

  # -----------------------------------------
  # Status mapping (code → readable label)
  # -----------------------------------------
  STATUS_MAP = {
    "A" => "Actif",
    "I" => "Inactif",
    "P" => "Plannifé",
    "C" => "Annulé",
    "S" => "Suspendu"
  }

  # Returns the readable status name for this service.
  def status_name
    STATUS_MAP[purchase_status]
  end

  # -----------------------------------------
  # Convenience Scopes / Collections
  # -----------------------------------------
  # Returns only confirmed sessions for this service.
  def confirmed_sessions
    sessions.confirmed
  end

  # Returns only paid sessions.
  def paid_sessions
    sessions.paid
  end

  # Returns only free sessions.
  def free_sessions
    sessions.free
  end

  # -----------------------------------------
  # Adjustment sums (converted to float for safety)
  # -----------------------------------------
  # Total bonus sessions granted through adjustments.
  def bonus_sessions_total
    service_usage_adjustments.sum(:bonus_sessions).to_f
  end

  # Net change in paid sessions used due to adjustments.
  def paid_used_adjustment
    service_usage_adjustments.sum(:paid_used_delta).to_f
  end

  # Net change in free sessions used due to adjustments.
  def free_used_adjustment
    service_usage_adjustments.sum(:free_used_delta).to_f
  end

  # -----------------------------------------
  # Usage Totals (sessions + adjustments)
  # -----------------------------------------
  # Total paid sessions used, combining actual booked durations and adjustments.
  def paid_used_total
    paid_sessions.sum(:duration).to_f + paid_used_adjustment
  end

  # Total free sessions used, combining actual booked durations and adjustments.
  def free_used_total
    free_sessions.sum(:duration).to_f + free_used_adjustment
  end

  # -----------------------------------------
  # Allowed Totals
  # -----------------------------------------
  # Maximum number of paid sessions allowed (from definition + bonuses).
  def paid_allowed_total
    base = service_definition&.paid_sessions.to_f
    base + bonus_sessions_total
  end

  # Maximum number of free sessions allowed (from definition only).
  def free_allowed_total
    service_definition&.free_sessions.to_f
  end

  # -----------------------------------------
  # Remaining Sessions (clamped to 0.0)
  # -----------------------------------------
  # Remaining paid sessions the user can book.
  # Returns nil if there is no definition and no base total.
  def remaining_paid_sessions
    total = paid_allowed_total
    return nil if total.zero? && service_definition.nil?
    [total - paid_used_total, 0.0].max
  end

  # Remaining free sessions the user can book.
  # Returns nil if there is no definition and no base total.
  def remaining_free_sessions
    total = free_allowed_total
    return nil if total.zero? && service_definition.nil?
    [total - free_used_total, 0.0].max
  end

  # -----------------------------------------
  # Usage Statistics (compact hash for views/API)
  # -----------------------------------------
  # Provides a structured breakdown of paid and free usage stats.
  def usage_stats
    {
      paid: {
        used_sessions:  paid_used_total,
        included:       service_definition&.paid_sessions,
        bonus:          bonus_sessions_total,
        allowed_total:  paid_allowed_total,
        remaining:      remaining_paid_sessions
      },
      free: {
        used_sessions:  free_used_total,
        included:       service_definition&.free_sessions,
        allowed_total:  free_allowed_total,
        remaining:      remaining_free_sessions
      }
    }
  end

  # -----------------------------------------
  # Booking Logic
  # -----------------------------------------
  # Determines the next session type that can be booked:
  #   - Prioritizes free sessions if any remain.
  #   - Falls back to paid if free is exhausted.
  #   - Returns nil if neither type is available.
  def next_session_type
    return "free" if remaining_free_sessions.to_f > 0.0
    return "paid" if remaining_paid_sessions.to_f > 0.0
    nil
  end

  # True if there is at least one free or paid session available to book.
  def can_book_session?
    next_session_type.present?
  end

  # -----------------------------------------
  # Progress Percentages
  # -----------------------------------------
  # Percentage of paid sessions used out of the total allowed.
  def paid_progress_percent
    total = paid_allowed_total
    return nil if total.to_f <= 0.0
    ((paid_used_total / total) * 100).round
  end

  # Percentage of free sessions used out of the total allowed.
  def free_progress_percent
    total = free_allowed_total
    return nil if total.to_f <= 0.0
    ((free_used_total / total) * 100).round
  end

    # --- Time window progress (date-based) ---
  # We assume start_date/expire_date come from API and are present most of the time.
  # Still clamp and guard if expire < start for safety.
  def time_progress_percent(today: Date.current)
    return nil if start_date.blank? || expire_date.blank? || expire_date < start_date

    total_days = (expire_date - start_date).to_f
    return nil if total_days <= 0.0

    elapsed = (today - start_date).to_f
    pct     = ((elapsed / total_days) * 100).clamp(0.0, 100.0)
    pct.round
  end

  def time_range_label
    return "—" if start_date.blank? || expire_date.blank?
    "#{start_date.strftime('%d/%m/%Y')} – #{expire_date.strftime('%d/%m/%Y')}"
  end

  # --- Paid usage breakdown for display (pre-formatted) ---
  def paid_breakdown
    used  = paid_used_total.to_f
    base  = service_definition&.paid_sessions
    bonus = bonus_sessions_total.to_f
    allow = paid_allowed_total.to_f
    pct   = paid_progress_percent # may be nil if no allowed

    {
      used: used, included: base, bonus: bonus, allowed: allow, percent: pct,
      used_str: format('%.1f', used),
      included_str: base.nil? ? "—" : base.to_s,
      bonus_str: format('%.1f', bonus),
      allowed_str: allow.positive? ? format('%.1f', allow) : "—",
      percent_str: pct.nil? ? "—" : pct.to_s
    }
  end

  # --- Paid usage breakdown for display ---
  # Returns: "12.5/(48.0 + 0.0)"
  def paid_usage_compact_str
    used  = paid_used_total.to_f
    base  = service_definition&.paid_sessions.to_f
    bonus = bonus_sessions_total.to_f
    "#{format('%.1f', used)}/(#{format('%.1f', base)} + #{format('%.1f', bonus)})"
  end

  # Returns: "[1.0/4.0 absences]" or "[1.0/— absences]" if allowed is unknown
  def absences_compact_str
    "[#{format('%.1f', free_used_total)}/#{free_allowed_total} absences]"
  end
end
