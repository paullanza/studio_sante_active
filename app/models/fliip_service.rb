class FliipService < ApplicationRecord
  has_many :sessions
  belongs_to :fliip_user
  has_one :service_definition, primary_key: :service_id, foreign_key: :service_id

  def confirmed_sessions
    sessions.where(confirmed: true)
  end

  def confirmed_present_sessions
    confirmed_sessions.where(present: true).count
  end

  def confirmed_absent_sessions
    confirmed_sessions.where(present: false).count
  end

  def remaining_paid_sessions
    return nil unless service_definition

    total = service_definition.paid_sessions
    used = confirmed_present_sessions + [confirmed_absent_sessions - service_definition.free_sessions, 0].max
    [total - used, 0].max
  end

  def remaining_free_sessions
    return nil unless service_definition

    total = service_definition.free_sessions
    used = confirmed_absent_sessions
    [total - used, 0].max
  end
end
