class SignupCode < ApplicationRecord
  # -----------------------------------------
  # Associations
  # -----------------------------------------
  # Each signup code can optionally be linked to a user who has used it.
  # `used_by_id` will store the ID of the user who redeemed the code.
  belongs_to :used_by, class_name: "User", optional: true

  # -----------------------------------------
  # Enum: Status values
  # -----------------------------------------
  # :active      - Code can still be used and has not expired.
  # :deactivated - Code was manually disabled before use/expiry.
  # :used        - Code has been redeemed by a user.
  # :expired     - Code expired due to time passing.
  enum status: [:active, :deactivated, :used, :expired]

  # -----------------------------------------
  # Validations
  # -----------------------------------------
  # - Code: must be present, unique, and exactly 8 characters long.
  # - Status: must be present (valid enum value).
  # - Expiry date: must be present.
  validates :code, presence: true, uniqueness: true, length: { is: 8 }
  validates :status, presence: true
  validates :expiry_date, presence: true

  # -----------------------------------------
  # Callbacks
  # -----------------------------------------
  # When creating a code:
  #   1. Generate a unique 8-character code if none is provided.
  #   2. Set a default expiry date (14 days from creation) if none provided.
  before_validation :generate_code, on: :create
  before_validation :set_expiry_date, on: :create

  # -----------------------------------------
  # Scopes
  # -----------------------------------------
  # Returns codes that are active and have not yet expired.
  scope :usable, -> { active.where("expiry_date > ?", Time.current) }

  # -----------------------------------------
  # Instance Methods
  # -----------------------------------------

  # True if the code is active and has not expired yet.
  def usable?
    active? && expiry_date.future?
  end

  # True if the code is active but has already passed its expiry date.
  def expired_by_time?
    active? && expiry_date.past?
  end

  # Marks the code as expired if it is active but past its expiry date.
  def mark_as_expired!
    return false unless expired_by_time?
    update!(status: :expired)
  end

  # Marks the code as used by a specific user.
  # This also links the `used_by` association.
  def used!(by:)
    update!(status: :used, used_by: by)
  end

  # Class method:
  # Iterates over all active codes past their expiry date and marks them as expired.
  def self.expire_old_codes!
    active.where("expiry_date < ?", Time.current).find_each do |code|
      code.update!(status: :expired)
    end
  end

  # Deactivates a code before expiry if it is currently active and still valid.
  def safely_deactivate!
    return false unless active? && expiry_date.future?
    update!(status: :deactivated)
  end

  private

  # -----------------------------------------
  # Callback Helpers
  # -----------------------------------------

  # Generates a unique 8-character code if none is already set.
  # The code consists of uppercase letters and digits, but excludes:
  #   - 0 and O (to avoid confusion)
  #   - 1, I, and L (to avoid confusion)
  # The loop ensures uniqueness by checking existing codes.
  def generate_code
    return if code.present?

    chars = ('A'..'Z').to_a.concat(('0'..'9').to_a) - %w[0 O 1 I L]

    loop do
      self.code = Array.new(8) { chars.sample }.join
      break unless SignupCode.exists?(code: code)
    end
  end

  # Sets a default expiry date if none is given.
  # Default: 14 days from the time of creation.
  def set_expiry_date
    self.expiry_date = 14.days.from_now if expiry_date.nil?
  end
end
