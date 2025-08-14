class ServiceUsageAdjustment < ApplicationRecord
  belongs_to :fliip_service
  belongs_to :user

  validates :paid_used_delta, :free_used_delta, :paid_bonus_delta,
            numericality: true,allow_nil: true
end
