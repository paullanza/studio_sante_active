class Session < ApplicationRecord
  belongs_to :user
  belongs_to :fliip_user
  belongs_to :fliip_service

  validates :date, :time, presence: true
  validates :fliip_user_id, uniqueness: {
    scope: [:fliip_service_id, :date, :time],
    message: "already has a session at this time with this service"
  }
  validate :service_is_active, on: :create

  def service_is_active
    errors.add(:base, "The service has ended.") if date > fliip_service.expire_date.next_month

    errors.add(:base, "The service has not started.") if date < fliip_service.start_date.last_month
  end

  scope :unconfirmed, -> { where(confirmed: false) }
  scope :confirmed, -> { where(confirmed: true) }

  before_validation :set_session_type_and_duration, on: :create

  def duration_display
    case duration
    when 1.0 then "1 hour"
    when 0.5 then "30 minutes"
    end
  end

  private

  def set_session_type_and_duration
    if present
      self.session_type = "paid"
    else
      used_free = fliip_service.sessions.where(present: false, session_type: "free").sum(:duration)
      available_free = fliip_service.service_definition.free_sessions.to_f

      self.session_type = used_free < available_free ? "free" : "paid"
    end
  end
end
