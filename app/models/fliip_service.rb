# app/models/fliip_service.rb
class FliipService < ApplicationRecord
  belongs_to :fliip_user
  has_many   :sessions, dependent: :nullify
  has_one    :service_definition, primary_key: :service_id, foreign_key: :service_id
  has_many :service_usage_adjustments, dependent: :destroy

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
  def paid_bonus_total
    service_usage_adjustments.sum(:paid_bonus_delta).to_f
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

  # --- Allowed totals (base from definition + bonus) ---
  def paid_allowed_total
    base = service_definition&.paid_sessions.to_f
    base + paid_bonus_total
  end

  def free_allowed_total
    service_definition&.free_sessions.to_f
  end

  # --- Remaining (clamped at 0.0) ---
  def remaining_paid_sessions
    total = paid_allowed_total
    return nil if total.zero? && service_definition.nil? # keep your original nil semantics
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
        bonus:          paid_bonus_total,
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

  # --- Nice-to-have for progress bars (0–100) ---
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
