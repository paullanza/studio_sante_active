# app/models/service_usage_adjustment.rb
class ServiceUsageAdjustment < ApplicationRecord
  # -----------------------------------------
  # Associations
  # -----------------------------------------
  # The service whose usage is being adjusted.
  belongs_to :fliip_service, inverse_of: :service_usage_adjustments

  # The staff member who created or authorized the adjustment.
  belongs_to :user,          inverse_of: :service_usage_adjustments

  # Shortcut: retrieve the client associated with the service.
  has_one :fliip_user, through: :fliip_service

  # -----------------------------------------
  # Validations
  # -----------------------------------------
  # These fields can be nil, but if present they must be numeric:
  #   - paid_used_delta   → Adjusts the count of paid sessions used (positive or negative)
  #   - free_used_delta   → Adjusts the count of free sessions used (positive or negative)
  #   - bonus_sessions    → Grants or removes bonus paid sessions
  validates :paid_used_delta, :free_used_delta, :bonus_sessions,
            numericality: true, allow_nil: true

  # Custom validation: require at least one of the adjustment fields
  # to be non-zero so we don’t save “empty” adjustments.
  validate :at_least_one_delta_present

  # -----------------------------------------
  # Scopes
  # -----------------------------------------
  # Filters adjustments that modify paid session usage.
  scope :with_paid_delta, -> { where.not(paid_used_delta: [nil, 0]) }

  # Filters adjustments that modify free session usage.
  scope :with_free_delta, -> { where.not(free_used_delta: [nil, 0]) }

  # Filters adjustments that grant/remove bonus sessions.
  scope :with_bonus,      -> { where.not(bonus_sessions: [nil, 0]) }

  private

  # -----------------------------------------
  # Validation Helper
  # -----------------------------------------
  # Ensures that at least one adjustment field is provided
  # and is non-zero. Prevents creation of no-op adjustments.
  def at_least_one_delta_present
    p = paid_used_delta.to_f
    f = free_used_delta.to_f
    b = bonus_sessions.to_f
    if p.zero? && f.zero? && b.zero?
      errors.add(:base, "Provide at least one non-zero adjustment.")
    end
  end
end
