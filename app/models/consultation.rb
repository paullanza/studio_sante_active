class Consultation < ApplicationRecord
  include PgSearch::Model

  # -----------------------------------------
  # Full-text search (accent-insensitive)
  # -----------------------------------------
  pg_search_scope :search_identity,
    against: [:first_name, :last_name, :email, :phone_number],
    using: { tsearch: { prefix: true, normalization: 2 } },
    ignoring: :accents

  # -----------------------------------------
  # Associations
  # -----------------------------------------
  belongs_to :user
  belongs_to :created_by, class_name: "User"
  belongs_to :fliip_user, optional: true
  belongs_to :fliip_service, optional: true
  # The admin who confirmed it for payroll; nil before confirmation and on
  # confirmations made before it was recorded.
  belongs_to :confirmed_by, class_name: "User", optional: true

  # -----------------------------------------
  # Validations
  # -----------------------------------------
  validates :user_id, :first_name, :last_name, :occurred_at, presence: true
  validates :note, length: { maximum: 10_000 }, allow_blank: true

  # A phone or an email, to reach the prospect.
  validate :phone_or_email_present
  # Stored as 10 digits. Checked only when the phone changes, so older rows
  # with an odd phone still save when other fields change.
  validates :phone_number, format: { with: /\A\d{10}\z/, message: "doit contenir 10 chiffres" },
                           allow_nil: true, if: :will_save_change_to_phone_number?
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP, message: "est invalide" }, allow_blank: true
  # Always logged on new consultations; older rows can have nil and stay editable.
  validates :present, inclusion: { in: [ true, false ], message: "doit être indiqué" }, on: :create

  validates :fliip_service_id,
            uniqueness: { message: "has already been associated to another consultation" },
            allow_nil: true

  # -----------------------------------------
  # Callbacks
  # -----------------------------------------
  before_validation :default_created_by, on: :create
  before_validation :normalize_phone_number, if: :will_save_change_to_phone_number?
  before_validation :normalize_email

  # ⛔️ Removed name-mirroring callbacks so we keep the user-typed name
  # after_save :sync_names_from_service, if: :saved_change_to_fliip_service_id?
  # after_save :sync_names_from_client,  if: :saved_change_to_fliip_user_id?

  # -----------------------------------------
  # Status scopes
  # -----------------------------------------
  scope :unconfirmed,  -> { where(confirmed: [false, nil]) }
  scope :confirmed,    -> { where(confirmed: true) }
  scope :unassociated, -> { where(fliip_user_id: nil) }
  # Consultations that took place in a pay period (PayPeriod), Sunday to Saturday.
  scope :in_period, ->(period) {
    where(occurred_at: period.starts_on.beginning_of_day..period.ends_on.end_of_day)
  }

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
  # Confirms for payroll and records who did it. Idempotent: only touches
  # unconfirmed consultations. Returns how many it confirmed.
  def self.confirm(ids, by:)
    ids = Array(ids).map(&:to_i).uniq
    return 0 if ids.empty?

    where(id: ids).unconfirmed.update_all(
      confirmed: true,
      confirmed_at: Time.current,
      confirmed_by_id: by.id
    )
  end

  # -----------------------------------------
  # UI helpers
  # -----------------------------------------
  def full_name
    [first_name, last_name].compact.join(" ").strip
  end

  # Association window (−14 days, +3 months from occurred_at)
  def association_start_window
    base = occurred_at.to_date
    (base - 14.days)..(base + 3.months)
  end

  private

  # « (514) 555-0142 », « 514.555.0142 » and « 1 514 555 0142 » all become
  # « 5145550142 ». Anything else keeps its digits (or, with none, what was
  # typed) and fails the format check. Blank becomes nil.
  def normalize_phone_number
    return self.phone_number = nil if phone_number.blank?

    digits = phone_number.gsub(/\D/, "")
    digits = digits.delete_prefix("1") if digits.size == 11 && digits.start_with?("1")
    self.phone_number = digits.presence || phone_number.strip
  end

  def normalize_email
    self.email = email.to_s.strip.downcase.presence if email
  end

  def phone_or_email_present
    return if phone_number.present? || email.present?

    errors.add(:base, "Indiquez un téléphone ou un courriel.")
  end

  def default_created_by
    self.created_by_id = user_id if self.created_by_id.blank?
  end
end
