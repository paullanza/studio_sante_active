class SignupCode < ApplicationRecord
  belongs_to :used_by, class_name: "User", optional: true

  enum status: [:active, :deactivated, :used, :expired]

  validates :code, presence: true, uniqueness: true, length: { is: 8 }
  validates :status, presence: true
  validates :expiry_date, presence: true

  before_validation :generate_code, on: :create
  before_validation :set_expiry_date, on: :create

  scope :usable, -> { active.where("expiry_date > ?", Time.current) }

  def usable?
    active? && expiry_date.future?
  end

  def expired_by_time?
    active? && expiry_date.past?
  end

  def mark_as_expired!
    return false unless expired_by_time?
    update!(status: :expired)
  end

  def used!(by:)
    update!(status: :used, used_by: by)
  end

  def self.expire_old_codes!
    active.where("expiry_date < ?", Time.current).find_each do |code|
      code.update!(status: :expired)
    end
  end

  def safely_deactivate!
    return false unless active? && expiry_date.future?
    update!(status: :deactivated)
  end

  private

  def generate_code
    return if code.present?

    chars = ('A'..'Z').to_a.concat(('0'..'9').to_a) - %w[0 O 1 I L]

    loop do
      self.code = Array.new(8) { chars.sample }.join
      break unless SignupCode.exists?(code: code)
    end
  end

  def set_expiry_date
    self.expiry_date = 14.days.from_now if expiry_date.nil?
  end
end
