class User < ApplicationRecord
  # -----------------------------------------
  # Devise authentication modules
  # -----------------------------------------
  # :database_authenticatable - Handles hashing and storing a password in the database
  # :registerable             - Allows users to sign up
  # :recoverable              - Handles resetting passwords
  # :rememberable             - Manages generating and clearing token for remembering the user from a saved cookie
  # :validatable              - Adds validations for email and password
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  # -----------------------------------------
  # Associations
  # -----------------------------------------
  # Each user can have at most one SignupCode that they have used (foreign key `used_by_id` on SignupCode model)
  # If the user is deleted, the `used_by_id` is set to NULL in the associated SignupCode
  has_one :signup_code, foreign_key: "used_by_id", inverse_of: :used_by, dependent: :nullify

  # A user can have many sessions they have created or are associated with
  has_many :sessions

  # A user can have many service usage adjustments; if user is deleted, keep the adjustments but nullify the user link
  has_many :service_usage_adjustments, dependent: :nullify

  # -----------------------------------------
  # Virtual Attributes
  # -----------------------------------------
  # This is not stored in the DB; it holds the signup code entered during registration
  attr_accessor :signup_code_token

  # -----------------------------------------
  # Roles
  # -----------------------------------------
  # Defines role-based enum values for authorization and permissions
  # Possible roles: employee (0), manager (1), admin (2), super_admin (3)
  enum role: [:employee, :manager, :admin, :super_admin]

  ROLE_LABELS_FR = {
    "employee"    => "Employé·e",
    "manager"     => "Gestionnaire",
    "admin"       => "Admin",
    "super_admin" => "Admin"
  }.freeze

  # Human-readable role in FR-CA for display
  def translated_role
    ROLE_LABELS_FR[role.to_s] || role.to_s.humanize
  end

  # Only allow login when active == true
  def active_for_authentication?
    super && active?
  end

  # Customize the flash shown by Devise on failed login
  def inactive_message
    active? ? super : :inactive # uses devise.failure.inactive
  end

  # -----------------------------------------
  # Scopes
  # -----------------------------------------
  # Quick access methods for active and inactive users
  scope :active,   -> { where(active: true) }
  scope :inactive, -> { where(active: false) }

  # -----------------------------------------
  # Validations
  # -----------------------------------------
  # Require these fields for all users
  validates :first_name, :last_name, :phone, :address, :birthday,
            presence: { message: "ne peut pas être vide" }

  # Ensure the provided signup code is valid when creating a user
  validate  :validate_signup_code, on: :create

  # -----------------------------------------
  # Callbacks
  # -----------------------------------------
  # After the user is created, mark their signup code as used (if valid)
  after_create :consume_signup_code

  # -----------------------------------------
  # Instance Methods
  # -----------------------------------------

  # Determines if the given actor can change the active/inactive status of this user
  # Rules:
  #   - Cannot change your own active status
  #   - super_admin and admin can change anyone's status
  #   - manager can only change employee status
  def active_status_change_allowed?(actor)
    return false if actor == self
    actor.super_admin? || actor.admin? || (actor.manager? && employee?)
  end

  # Activates the user if the actor has permission
  def activate_by!(actor)
    unless active_status_change_allowed?(actor)
      errors.add(:base, "Vous n’avez pas l’autorisation d’activer cet·te utilisateur·trice")
      return false
    end

    update!(active: true)
  end

  # Deactivates the user if the actor has permission
  def deactivate_by!(actor)
    unless active_status_change_allowed?(actor)
      errors.add(:base, "Vous n’avez pas l’autorisation de désactiver cet·te utilisateur·trice")
      return false
    end

    update!(active: false)
  end

  # Returns the user's full name by combining first and last names
  def full_name
    "#{first_name} #{last_name}"
  end

  private

  # -----------------------------------------
  # Validation Helpers
  # -----------------------------------------

  # Ensures the signup code entered at registration is:
  #   - Present
  #   - Exists in the system
  #   - Not deactivated
  #   - Not already used
  #   - Not expired
  # This runs only during user creation
  def validate_signup_code
    if signup_code_token.blank?
      errors.add(:signup_code_token, "ne peut pas être vide")
      return
    end

    code = SignupCode.find_by(code: signup_code_token)
    if code.nil?
      errors.add(:signup_code_token, "est invalide")
    elsif code.deactivated?
      errors.add(:signup_code_token, "a été désactivé")
    elsif code.used?
      errors.add(:signup_code_token, "a déjà été utilisé")
    elsif code.expired? || code.respond_to?(:expired_by_time?) && code.expired_by_time?
      errors.add(:signup_code_token, "a expiré")
    end
  end

  # -----------------------------------------
  # Callback Helpers
  # -----------------------------------------

  # Marks the signup code as used by this user after creation
  # Uses a DB lock to prevent race conditions if multiple users try the same code
  # Only proceeds if the code is still usable
  def consume_signup_code
    code = SignupCode.lock.find_by(code: signup_code_token)
    return unless code&.usable?

    code.used!(by: self)
  end
end
