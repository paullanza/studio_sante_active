class Session < ApplicationRecord
  belongs_to :user
  belongs_to :fliip_user
  belongs_to :fliip_service

  validates :date, :time, :present, presence: true
  validates :fliip_user_id, uniqueness: {
    scope: [:fliip_service_id, :date, :time],
    message: "already has a session at this time with this service"
  }
end
