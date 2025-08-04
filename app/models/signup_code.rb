class SignupCode < ApplicationRecord
  belongs_to :used_by, class_name: "User", optional: true

  enum status: [:active, :deactivated, :used, :expired]

  validates :code, presence: true, uniqueness: true, length: { is: 8 }
  validates :status, presence: true
  validates :expiry_date, presence: true

  before_validation :generate_code, on: :create
  before_validation :set_expiry_date, on: :create

  # Returns true if the code is valid and can be used
  def usable?
    active? && expiry_date.future?
  end

  # Returns true if the code should now be expired (for internal checks)
  def expired_by_time?
    active? && expiry_date.past?
  end

  # Optionally call this to change the status if the code is expired
  def mark_as_expired!
    update!(status: :expired) if expired_by_time?
  end

  def used!
    self.status = :used
  end

  def self.expire_old_codes!
    active.where("expiry_date < ?", Time.current).find_each do |code|
      code.update!(status: :expired)
    end
  end

  def safely_deactivate!
    return false unless active? && expiry_date.future?

    update!(status: :deactivated)
    true
  end

  private

  def generate_code
    return if code.present?

    loop do
      self.code = SecureRandom.alphanumeric(8).upcase
      break unless SignupCode.exists?(code: code)
    end
  end

  def set_expiry_date
    self.expiry_date = 14.days.from_now if expiry_date.nil?
  end
end
