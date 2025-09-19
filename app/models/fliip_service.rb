class FliipService < ApplicationRecord
  # -----------------------------------------
  # Associations
  # -----------------------------------------
  belongs_to :fliip_user, inverse_of: :fliip_services
  has_many   :sessions, dependent: :restrict_with_error, inverse_of: :fliip_service
  belongs_to :service_definition,
              primary_key: :service_id,
              foreign_key: :service_id,
              optional: true
  has_many   :service_usage_adjustments, dependent: :destroy, inverse_of: :fliip_service

  # -----------------------------------------
  # Scopes: by purchase status
  # -----------------------------------------
  scope :active,    -> { where(purchase_status: "A") }
  scope :inactive,  -> { where(purchase_status: "I") }
  scope :planned,   -> { where(purchase_status: "P") }
  scope :cancelled, -> { where(purchase_status: "C") }
  scope :stopped,   -> { where(purchase_status: "S") }

  # NEW: filter by a set of status codes (expects an Array of "A"/"I"/"P"/"C"/"S")
  scope :by_statuses, ->(statuses) {
    statuses.present? ? where(purchase_status: statuses) : all
  }

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

  def status_name
    STATUS_MAP[purchase_status]
  end

  # -----------------------------------------
  # Convenience Scopes / Collections
  # -----------------------------------------
  def confirmed_sessions
    sessions.confirmed
  end

  def paid_sessions
    sessions.paid
  end

  def free_sessions
    sessions.free
  end

  # -----------------------------------------
  # Adjustment sums (converted to float for safety)
  # -----------------------------------------
  def bonus_sessions_total
    service_usage_adjustments.sum(:bonus_sessions).to_f
  end

  def paid_used_adjustment
    service_usage_adjustments.sum(:paid_used_delta).to_f
  end

  def free_used_adjustment
    service_usage_adjustments.sum(:free_used_delta).to_f
  end

  # -----------------------------------------
  # Usage Totals (sessions + adjustments)
  # -----------------------------------------
  def paid_used_total
    paid_sessions.sum(:duration).to_f + paid_used_adjustment
  end

  def free_used_total
    free_sessions.sum(:duration).to_f + free_used_adjustment
  end

  # -----------------------------------------
  # Allowed Totals
  # -----------------------------------------
  def paid_allowed_total
    base = service_definition&.paid_sessions.to_f
    base + bonus_sessions_total
  end

  def free_allowed_total
    service_definition&.free_sessions.to_f
  end

  # -----------------------------------------
  # Remaining Sessions (clamped to 0.0)
  # -----------------------------------------
  def remaining_paid_sessions
    total = paid_allowed_total
    return nil if total.zero? && service_definition.nil?
    [total - paid_used_total, 0.0].max
  end

  def remaining_free_sessions
    total = free_allowed_total
    return nil if total.zero? && service_definition.nil?
    [total - free_used_total, 0.0].max
  end

  # -----------------------------------------
  # Usage Statistics (compact hash for views/API)
  # -----------------------------------------
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
  def next_session_type
    return "free" if remaining_free_sessions.to_f > 0.0
    return "paid" if remaining_paid_sessions.to_f > 0.0
    nil
  end

  def can_book_session?
    next_session_type.present?
  end

  # -----------------------------------------
  # Progress Percentages
  # -----------------------------------------
  def paid_progress_percent
    total = paid_allowed_total
    return nil if total.to_f <= 0.0
    ((paid_used_total / total) * 100).round
  end

  def free_progress_percent
    total = free_allowed_total
    return nil if total.to_f <= 0.0
    ((free_used_total / total) * 100).round
  end

  # --- Time window progress (date-based) ---
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

  def paid_breakdown
    used  = paid_used_total.to_f
    base  = service_definition&.paid_sessions
    bonus = bonus_sessions_total.to_f
    allow = paid_allowed_total.to_f
    pct   = paid_progress_percent

    {
      used: used, included: base, bonus: bonus, allowed: allow, percent: pct,
      used_str: format('%.1f', used),
      included_str: base.nil? ? "—" : base.to_s,
      bonus_str: format('%.1f', bonus),
      allowed_str: allow.positive? ? format('%.1f', allow) : "—",
      percent_str: pct.nil? ? "—" : pct.to_s
    }
  end

  def paid_usage_compact_str
    used  = paid_used_total.to_f
    base  = service_definition&.paid_sessions.to_f
    bonus = bonus_sessions_total.to_f
    "#{format('%.1f', used)}/(#{format('%.1f', base)} + #{format('%.1f', bonus)})"
  end

  def absences_compact_str
    "[#{format('%.1f', free_used_total)}/#{free_allowed_total} absences]"
  end
end
