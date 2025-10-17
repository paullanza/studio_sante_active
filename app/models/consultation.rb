class Consultation < ApplicationRecord
  # -----------------------------------------
  # Associations
  # -----------------------------------------
  belongs_to :user
  belongs_to :created_by, class_name: "User"

  # -----------------------------------------
  # Validations
  # -----------------------------------------
  validates :user_id, :first_name, :last_name, :occurred_at, presence: true
  validates :note, length: { maximum: 10_000 }, allow_blank: true

  # -----------------------------------------
  # Callbacks
  # -----------------------------------------
  before_validation :default_created_by, on: :create

  # Status
  scope :unconfirmed, -> { where(confirmed: [false, nil]) }
  scope :confirmed,   -> { where(confirmed: true) }

  # Preload & order — même style que Session
  scope :with_associations, -> { includes(:user, :created_by) }
  scope :order_by_occurred_at_desc, -> { order(Arel.sql("occurred_at DESC NULLS LAST"), created_at: :desc) }

  def modifiable_by?(current_user)
    # Admin-like users: full powers
    return true if current_user&.admin? || current_user&.super_admin?

    # Employees/Managers: only if unconfirmed AND they are the owner
    !confirmed? && user_id == current_user&.id
  end

  private

  def default_created_by
    if created_by_id.blank?
      self.created_by_id = user_id
    end
  end
end
