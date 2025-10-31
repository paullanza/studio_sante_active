class Consultation < ApplicationRecord
  include PgSearch::Model

  # -----------------------------------------
  # Full-text search (accent-insensitive)
  # -----------------------------------------
  pg_search_scope :search_identity,
    against: [:first_name, :last_name, :email, :phone_number],
    using: {
      tsearch: { prefix: true, normalization: 2 }
    },
    ignoring: :accents

  # -----------------------------------------
  # Associations
  # -----------------------------------------
  belongs_to :user
  belongs_to :created_by, class_name: "User"
  belongs_to :fliip_service, optional: true

  # -----------------------------------------
  # Validations
  # -----------------------------------------
  validates :user_id, :first_name, :last_name, :email, :occurred_at, presence: true
  validates :note, length: { maximum: 10_000 }, allow_blank: true

  validates :fliip_service_id,
  uniqueness: { message: "has already been associated to another consultation" },
  allow_nil: true

  # -----------------------------------------
  # Callbacks
  # -----------------------------------------
  before_validation :default_created_by, on: :create

  # -----------------------------------------
  # Status scopes
  # -----------------------------------------
  scope :unconfirmed, -> { where(confirmed: [false, nil]) }
  scope :confirmed,   -> { where(confirmed: true) }

  # -----------------------------------------
  # Eager loading & ordering
  # -----------------------------------------
  scope :with_associations, -> { includes(:user, :created_by, fliip_service: :fliip_user) }
  scope :order_by_occurred_at_desc, -> {
    order(Arel.sql("occurred_at DESC NULLS LAST"), created_at: :desc)
  }

  # -----------------------------------------
  # Filtering scopes (admin search)
  # -----------------------------------------
  scope :by_employee, ->(user_id) {
    where(user_id: user_id) if user_id.present?
  }

  scope :date_between, ->(from_date, to_date) {
    rel = all
    rel = rel.where("occurred_at::date >= ?", from_date) if from_date.present?
    rel = rel.where("occurred_at::date <= ?", to_date)   if to_date.present?
    rel
  }

  scope :created_between, ->(from_dt, to_dt) {
    rel = all
    rel = rel.where("created_at >= ?", from_dt) if from_dt.present?
    rel = rel.where("created_at <= ?", to_dt)   if to_dt.present?
    rel
  }

  scope :present_value, ->(present_param) {
    vals = Array(present_param).reject(&:blank?).map(&:to_s)
    if vals.include?("yes") && vals.include?("no")
      all
    elsif vals.include?("yes")
      where(present: true)
    elsif vals.include?("no")
      where(present: [false, nil])
    else
      all
    end
  }

  # -----------------------------------------
  # Filter composer
  # -----------------------------------------
  def self.apply_filters(params)
    rel = all
    rel = rel.search_identity(params[:q]) if params[:q].present?
    rel = rel.by_employee(params[:employee_id])
    rel = rel.date_between(params[:consultation_date_from], params[:consultation_date_to])
    rel = rel.created_between(params[:created_from], params[:created_to])
    rel = rel.present_value(params[:present])
    rel
  end

  # -----------------------------------------
  # Bulk confirmation
  # -----------------------------------------
  def self.confirm(ids)
    ids = Array(ids).map(&:to_i).uniq
    return 0 if ids.empty?

    where(id: ids).unconfirmed.update_all(
      confirmed: true,
      confirmed_at: Time.current
    )
  end

  # -----------------------------------------
  # Permissions
  # -----------------------------------------
  def modifiable_by?(current_user)
    return true if current_user&.admin? || current_user&.super_admin?
    !confirmed? && user_id == current_user&.id
  end

  # -----------------------------------------
  # UI helpers
  # -----------------------------------------
  def after_date
    (occurred_at || created_at).to_date
  end

  def guessed_full_name
    [first_name, last_name].compact.join(" ").strip
  end

  def prefill_query
    email.presence || phone_number.presence || guessed_full_name
  end

  private

  def default_created_by
    self.created_by_id = user_id if created_by_id.blank?
  end
end
