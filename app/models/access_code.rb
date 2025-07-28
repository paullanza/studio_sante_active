class AccessCode < ApplicationRecord
  # An access code can be redeemed by one user, but starts out unclaimed
  belongs_to :user, optional: true

  # Only codes that haven’t been used and are still active
  scope :available, -> { where(user_id: nil, used_at: nil, active: true) }

  # Make sure every code we generate is unique
  validates :code, presence: true, uniqueness: true

  # When we create a new record, generate its 8‑char code
  before_validation :generate_code, on: :create

  # Attempt to redeem this code for `user`. Returns true if successful, false otherwise
  def redeem(user)
    return false unless available?

    # This single update is atomic, so either both fields get set or neither does
    update(user: user, used_at: Time.current)
  end

  # Deactivate it so nobody can use it any more
  def deactivate!
    update(active: false)
  end

  private

  def generate_code
    # random 8‑char uppercase alphanumeric
    self.code = loop do
      tok = SecureRandom.alphanumeric(8).upcase
      break tok unless AccessCode.exists?(code: tok)
    end
  end
end
