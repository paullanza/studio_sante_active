class FliipService < ApplicationRecord
  has_many :sessions
  belongs_to :fliip_user
  has_one :service_definition, primary_key: :service_id, foreign_key: :service_id

  def confirmed_sessions
    sessions.confirmed
  end

  def paid_sessions
    sessions.where(session_type: "paid")
  end

  def free_sessions
    sessions.where(session_type: "free")
  end

  def remaining_paid_sessions
    return nil unless service_definition

    total = service_definition.paid_sessions.to_f
    used  = paid_sessions.sum(:duration).to_f
    [total - used, 0.0].max
  end

  def remaining_free_sessions
    return nil unless service_definition

    total = service_definition.free_sessions.to_f
    used  = free_sessions.sum(:duration).to_f
    [total - used, 0.0].max
  end

  def usage_stats
    paid_used  = paid_sessions.sum(:duration).to_f
    free_used  = free_sessions.sum(:duration).to_f
    paid_inc   = service_definition&.paid_sessions
    free_inc   = service_definition&.free_sessions

    {
      paid: { used_sessions: paid_used, included: paid_inc },
      free: { used_sessions: free_used, included: free_inc }
    }
  end
end
