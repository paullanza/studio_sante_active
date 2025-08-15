class User < ApplicationRecord
  # Devise modules
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  has_one :signup_code, foreign_key: "used_by_id", inverse_of: :used_by, dependent: :nullify
  has_many :sessions
  has_many :service_usage_adjustments, dependent: :nullify

  # Virtual attribute for the access code entered at signup
  attr_accessor :signup_code_token

  # Roles
  enum role: [:employee, :manager, :admin, :super_admin]

  # Scopes for active/inactive users
  scope :active,   -> { where(active: true) }
  scope :inactive, -> { where(active: false) }

  # Validations
  validates :first_name, :last_name, :phone, :address, :birthday, presence: true
  validate  :validate_signup_code, on: :create

  # Once created, consume the code
  after_create :consume_signup_code

  def active_status_change_allowed?(actor)
    return false if actor == self
    actor.super_admin? || actor.admin? || (actor.manager? && employee?)
  end

  # Activate this user if the actor has permission
  def activate_by!(actor)
    unless active_status_change_allowed?(actor)
      errors.add(:base, 'You do not have permission to activate this user')
      return false
    end

    update!(active: true)
  end

  # Deactivate this user if the actor has permission
  def deactivate_by!(actor)
    unless active_status_change_allowed?(actor)
      errors.add(:base, 'You do not have permission to deactivate this user')
      return false
    end

    update!(active: false)
  end

  def full_name
    "#{first_name} #{last_name}"
  end

  private

  def validate_signup_code
    if signup_code_token.blank?
      errors.add(:signup_code_token, "cannot be blank")
      return
    end

    code = SignupCode.find_by(code: signup_code_token)
    if code.nil?
      errors.add(:signup_code_token, "is invalid")
    elsif code.deactivated?
      errors.add(:signup_code_token, "has been deactivated")
    elsif code.used?
      errors.add(:signup_code_token, "has already been used")
    elsif code.expired? || code.respond_to?(:expired_by_time?) && code.expired_by_time?
      errors.add(:signup_code_token, "has expired")
    end
  end

  def consume_signup_code
    code = SignupCode.lock.find_by(code: signup_code_token)
    return unless code&.usable?

    code.used!(by: self)
  end
end
