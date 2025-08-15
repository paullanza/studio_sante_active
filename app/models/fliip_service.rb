class FliipService < ApplicationRecord
  belongs_to :fliip_user, inverse_of: :fliip_services
  has_many   :sessions, dependent: :restrict_with_error, inverse_of: :fliip_service
  belongs_to :service_definition,
              primary_key: :service_id,
              foreign_key: :service_id,
              optional: true
  has_many   :service_usage_adjustments, dependent: :destroy, inverse_of: :fliip_service

  scope :active,    -> { where(purchase_status: "A") }
  scope :inactive,  -> { where(purchase_status: "I") }
  scope :planned,   -> { where(purchase_status: "P") }
  scope :cancelled, -> { where(purchase_status: "C") }
  scope :stopped,   -> { where(purchase_status: "S") }

  scope :current, -> {
    where(purchase_status: "A")
      .where("start_date IS NULL OR start_date <= ?", Date.current)
      .where("expire_date IS NULL OR expire_date >= ?", Date.current)
  }

  STATUS_MAP = {
    "A" => "Active",
    "I" => "Inactive",
    "P" => "Planned",
    "C" => "Cancelled",
    "S" => "Stopped"
  }

  def status_name
    STATUS_MAP[purchase_status]
  end

  # --- Convenience scopes/collections ---
  def confirmed_sessions
    sessions.confirmed
  end

  def paid_sessions
    sessions.where(session_type: "paid")
  end

  def free_sessions
    sessions.where(session_type: "free")
  end

  # --- Adjustment sums (float-safe) ---
  def bonus_sessions_total
    service_usage_adjustments.sum(:bonus_sessions).to_f
  end

  def paid_used_adjustment
    service_usage_adjustments.sum(:paid_used_delta).to_f
  end

  def free_used_adjustment
    service_usage_adjustments.sum(:free_used_delta).to_f
  end

  # --- Used (sessions + adjustments) ---
  def paid_used_total
    paid_sessions.sum(:duration).to_f + paid_used_adjustment
  end

  def free_used_total
    free_sessions.sum(:duration).to_f + free_used_adjustment
  end

  # --- Allowed totals ---
  def paid_allowed_total
    base = service_definition&.paid_sessions.to_f
    base + bonus_sessions_total
  end

  def free_allowed_total
    service_definition&.free_sessions.to_f
  end

  # --- Remaining (clamped at 0.0) ---
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

  # --- Compact stats blob for views/API ---
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

  def next_session_type
    return "free" if remaining_free_sessions.to_f > 0.0
    return "paid" if remaining_paid_sessions.to_f > 0.0
    nil
  end

  def can_book_session?
    next_session_type.present?
  end

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
end
