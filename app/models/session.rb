class Session < ApplicationRecord
  include PgSearch::Model

  # -----------------------------------------
  # Enums
  # -----------------------------------------
  # Backed by an integer column in the DB (0, 1…)
  # We define the mapping explicitly so ordering stays stable.
  enum session_type: [:paid, :free]

  # -----------------------------------------
  # PGSearch: search by client or employee names
  # -----------------------------------------
  # FliipUser fields: user_firstname, user_lastname
  pg_search_scope :search_names,
    against: [], # we only search through associated models below
    associated_against: {
      fliip_user: [:user_firstname, :user_lastname]
    },
    using: {
      tsearch: { prefix: true, normalization: 2 }
    }

  # -----------------------------------------
  # Associations
  # -----------------------------------------
  # The staff member who created or is responsible for the session.
  belongs_to :user

  # Creator of the record (may differ from :user when admins create for others)
  belongs_to :created_by, class_name: "User"

  # The client (from Fliip) who is attending the session.
  belongs_to :fliip_user

  # The specific purchased service (from Fliip) that this session uses.
  belongs_to :fliip_service

  # -----------------------------------------
  # Validations
  # -----------------------------------------

  # Duration must be a positive number if present (e.g., 0.5 for 30 min, 1.0 for 1 hour).
  validates :duration, numericality: { greater_than: 0 }, allow_nil: true

  # These fields must always be provided when creating a session.
  validates :fliip_user_id, :fliip_service_id, :created_by_id, :occurred_at, presence: true

  # Prevents duplicate bookings:
  #   - Same client (fliip_user_id)
  #   - Same service (fliip_service_id)
  #   - Same occurred_at
  validates :fliip_user_id, uniqueness: {
    scope: [:fliip_service_id, :occurred_at],
    message: "already has a session at this time with this service"
  }

  # Custom validations (only on create):
  # - Checks that the service is active for the date of the session
  validate :service_is_active, on: :create
  # - Checks that booking the session does not exceed paid/free quotas
  validate :respect_quota_limits, on: :create
  # - Checks that the service is not cancelled and is within the booking window (today-based)
  validate :service_not_cancelled, on: :create
  validate :service_within_booking_window, on: :create

  # Ensures that the chosen service actually belongs to the selected client.
  validate :service_matches_client

  # -----------------------------------------
  # Callbacks
  # -----------------------------------------
  # Before validation on create:
  #   - Determine whether this session is "free" or "paid"
  #   - Set default duration if not provided
  before_validation :set_session_type_and_duration, on: :create

  #   - Default created_by to the responsible user when not explicitly set
  before_validation :default_created_by, on: :create

  # -----------------------------------------
  # Scopes (status)
  # -----------------------------------------
  # Sessions awaiting confirmation (false or nil).
  scope :unconfirmed, -> { where(confirmed: [false, nil]) }
  # Sessions that have been confirmed.
  scope :confirmed,   -> { where(confirmed: true) }

  # -----------------------------------------
  # Scopes (preloading & ordering)
  # -----------------------------------------

  # Order by the occurred_at value; include NULLS LAST to keep incomplete rows at the end
  scope :order_by_occurred_at_desc, -> {
    order(Arel.sql("occurred_at DESC NULLS LAST"))
  }
  scope :order_by_occurred_at_asc, -> {
    order(Arel.sql("occurred_at ASC NULLS FIRST"))
  }

  # Preload graph commonly needed by views to avoid N+1.
  scope :with_associations, -> {
    includes(:user, :created_by, :fliip_user, fliip_service: :service_definition)
  }

  scope :recent, -> { order(created_at: :desc) }

  # -----------------------------------------
  # Scopes (filters for server-side search)
  # -----------------------------------------

  scope :by_employee, ->(user_id) {
    # Accepts a single user_id. No-op if blank.
    where(user_id: user_id) if user_id.present?
  }

  scope :date_between, ->(from_date, to_date) {
    # from/to are expected as YYYY-MM-DD (Flatpickr submits ISO via hidden fields)
    rel = all
    rel = rel.where("occurred_at::date >= ?", from_date) if from_date.present?
    rel = rel.where("occurred_at::date <= ?", to_date)   if to_date.present?
    rel
  }

  scope :created_between, ->(from_dt, to_dt) {
    # from/to timestamps as strings are fine; DB handles casting
    rel = all
    rel = rel.where("created_at >= ?", from_dt) if from_dt.present?
    rel = rel.where("created_at <= ?", to_dt)   if to_dt.present?
    rel
  }

  # present_param accepts:
  #   - "yes", "no", "any"/nil (backward compatible)
  #   - OR an Array like ["yes", "no"], ["yes"], ["no"] (from checkbox groups)
  scope :present_value, ->(present_param) {
    vals = Array(present_param).reject(&:blank?).map(&:to_s)

    if vals.include?("yes") && vals.include?("no")
      all # both boxes checked → no filtering
    elsif vals.include?("yes")
      where(present: true)
    elsif vals.include?("no")
      where(present: [false, nil])
    else
      all # nil / "any" / [] → no filtering
    end
  }

  # type_param accepts:
  #   - "paid", "free", "any"/nil (backward compatible)
  #   - OR an Array like ["paid", "free"], ["paid"], ["free"]
  scope :of_type, ->(type_param) {
    vals = Array(type_param).reject(&:blank?).map(&:to_s)

    if vals.include?("paid") && vals.include?("free")
      all
    elsif vals.include?("paid")
      where(session_type: "paid")
    elsif vals.include?("free")
      where(session_type: "free")
    else
      all
    end
  }

  # Convenience: composes the common filter set in a single call.
  # Keep controllers skinny; still returns a Relation (chainable).
  def self.apply_filters(params)
    rel = all
    rel = rel.search_names(params[:q]) if params[:q].present?
    rel = rel.by_employee(params[:employee_id])
    rel = rel.date_between(params[:session_date_from], params[:session_date_to])
    rel = rel.created_between(params[:created_from], params[:created_to])
    rel = rel.present_value(params[:present])         # now supports single value OR array
    rel = rel.of_type(params[:session_type])          # now supports single value OR array
    rel
  end

  # -----------------------------------------
  # Display Helpers
  # -----------------------------------------
  # Returns a human-friendly display for the duration:
  #   - "1 hour" for 1.0
  #   - "30 minutes" for 0.5
  #   - "<value> h" for other values
  def duration_display
    case duration
    when 1.0 then "1 heure"
    when 0.5 then "Demi-heure"
    else          "#{duration.to_f} h"
    end
  end

  # Small helper used by the table to render presence meaning succinctly.
  # (Can be moved to a view helper later if you prefer.)
  def presence_label
    return "Présent" if present

    paid? ? "Absent (-24h)" : "Absent"
  end

  def date_time_label
    occurred_at&.strftime('%d/%m/%Y %H:%M') || ""
  end

  def created_at_label
    "créé : #{created_at.strftime('%d/%m/%Y %H:%M')}"
  end

  def presence_with_duration_label
    base = presence_label
    "#{duration_display} #{base}"
  end

  def presence_badge_variant
    return 'bg-success' if present
    paid? ? 'bg-danger' : 'bg-warning'
  end

  def modifiable_by?(current_user)
    # Admin-like users: full powers
    return true if current_user&.admin? || current_user&.super_admin?

    # Employees/Managers: only if unconfirmed AND they are the owner
    !confirmed? && user_id == current_user&.id
  end

  def self.confirm(ids)
    ids = Array(ids).map(&:to_i).uniq
    return 0 if ids.empty?

    # Idempotent: only touch currently-unconfirmed rows.
    where(id: ids).unconfirmed.update_all(
      confirmed: true,
      confirmed_at: Time.current
    )
  end

  # Sequence number within this FliipService & session_type (paid/free)
  # Based on creation time ascending; ties broken by id.
  #
  # Note: This is O(1) query but runs per-row; acceptable for moderate table sizes.
  # If you need to optimize for large lists, we can precompute via a window function.
  # Sequence number within this FliipService & session_type (paid/free)
  # Now based on occurred_at ascending (ties by id), plus adjustments that existed
  # at or before this session's occurred_at.
  def sequence_number_in_service
    return nil unless fliip_service_id && session_type && occurred_at

    # Sessions up to and including this one in occurred_at order
    sessions_count = Session
      .where(fliip_service_id: fliip_service_id, session_type: session_type)
      .where("occurred_at < :ts OR (occurred_at = :ts AND id <= :id)", ts: occurred_at, id: id)
      .count

    offset = adjustments_used_before_self
    sessions_count.to_f + offset.to_f
  end

  # Sum of “used” adjustments effective before this session occurs.
  # (Adjustments don’t have occurred_at, so we treat created_at as their effective time.)
  def adjustments_used_before_self
    return 0.0 unless fliip_service_id && occurred_at

    col = paid? ? :paid_used_delta : :free_used_delta

    ServiceUsageAdjustment
      .where(fliip_service_id: fliip_service_id)
      .where("created_at <= ?", occurred_at)
      .sum(col)
      .to_f
  end

  # Label like "Paid #7" or "Free #1"
  # Shorter variations: "P#7" / "F#1" if you want to go ultra-compact.
  def sequence_label
    n = sequence_number_in_service
    return nil unless n
    type = paid? ? "Séance" : "Absence"
    formatted = (n % 1 == 0) ? n.to_i : n.round(2)
    "#{type} ##{formatted}"
  end

  private

  # -----------------------------------------
  # Callback Helpers
  # -----------------------------------------
  # Determines the session type ("free" or "paid") and sets duration.
  #
  # Rules:
  # - Default duration is 1.0 hour unless provided.
  # - If present is true → always "paid".
  # - If no service definition exists → default to "paid" (can't evaluate free allowance).
  # - Otherwise:
  #     Use "free" if enough free sessions remain for the full duration.
  #     Otherwise, "paid".
  def set_session_type_and_duration
    self.duration = (duration.presence || 1.0).to_f

    return if fliip_service_id.blank? || fliip_service.nil?

    if present
      self.session_type = :paid
      return
    end

    if fliip_service.service_definition.nil?
      self.session_type = :paid
      return
    end

    free_remaining = fliip_service.remaining_free_sessions.to_f
    self.session_type = free_remaining >= duration ? :free : :paid
  end

  # Default creator fallback
  def default_created_by
    if created_by_id.blank?
      self.created_by_id = user_id
    end
  end

  # -----------------------------------------
  # Validation Helpers
  # -----------------------------------------

  # Prevent booking if quotas would be exceeded.
  # Uses FliipService's quota calculations (which include bonuses and adjustments).
  def respect_quota_limits
    return if fliip_service.blank?
    return if fliip_service.service_definition.nil?

    if session_type == "paid"
      remaining = fliip_service.remaining_paid_sessions.to_f
      if remaining < duration.to_f
        errors.add(:base, "Aucune séance payante disponible pour ce service.")
      end
    elsif session_type == "free"
      remaining = fliip_service.remaining_free_sessions.to_f
      if remaining < duration.to_f
        errors.add(:base, "Aucune absence gratuite disponible pour ce service.")
      end
    end
  end

  # Checks that the session date is within the service window,
  # allowing a 30-day grace period before start and after expiry.
  def service_is_active
    return if fliip_service.blank? || occurred_at.blank?

    session_date = occurred_at.to_date

    if fliip_service.expire_date.present? &&
       session_date > (fliip_service.expire_date + 30.days)
      errors.add(:base, "Le service est terminé depuis plus de 30 jours.")
    end

    if fliip_service.start_date.present? &&
       session_date < (fliip_service.start_date - 30.days)
      errors.add(:base, "La date de début de ce service est dans plus de 30 jours.")
    end
  end

  # Ensures the chosen service belongs to the selected client.
  def service_matches_client
    return if fliip_service.blank? || fliip_user_id.blank?
    if fliip_service.fliip_user_id != fliip_user_id
      errors.add(:fliip_service_id, "ne correspond pas au client sélectionné.")
    end
  end

  # Prevents booking on a cancelled service.
  def service_not_cancelled
    return if fliip_service.blank?
    if fliip_service.cancelled?
      errors.add(:base, "Ce service est annulé. Impossible de créer une séance.")
    end
  end

  # Prevents booking when service is too far in the past or future relative to today.
  def service_within_booking_window
    return if fliip_service.blank?

    today = Date.current

    if fliip_service.start_date.present? &&
       fliip_service.start_date > (today + 30.days)
      errors.add(:base, "La date de début de ce service est dans plus de 30 jours. Impossible de créer une séance.")
    end

    if fliip_service.expire_date.present? &&
       fliip_service.expire_date < (today - 30.days)
      errors.add(:base, "Ce service est terminé depuis plus de 30 jours. Impossible de créer une séance.")
    end
  end
end
