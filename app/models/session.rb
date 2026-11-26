class Session < ApplicationRecord
  include PgSearch::Model

  # -----------------------------------------
  # Enums
  # -----------------------------------------
  # Backed by an integer column in the DB (0, 1…)
  # We define the mapping explicitly so ordering stays stable.
  enum :session_type, [:paid, :free]

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

  # The admin who confirmed it for payroll; nil before confirmation and on
  # confirmations made before it was recorded.
  belongs_to :confirmed_by, class_name: "User", optional: true

  # -----------------------------------------
  # Validations
  # -----------------------------------------

  # A séance lasts 1 h or 30 min (GLOSSARY.md).
  DURATIONS = [ 0.5, 1.0 ].freeze
  validates :duration, inclusion: { in: DURATIONS, message: "doit être 1 h ou 30 min" }

  # These fields must always be provided when creating a session.
  validates :fliip_user_id, :fliip_service_id, :created_by_id, :occurred_at, presence: true

  # Prevents duplicate bookings:
  #   - Same client (fliip_user_id)
  #   - Same service (fliip_service_id)
  #   - Same occurred_at
  validates :fliip_user_id, uniqueness: {
    scope: [:fliip_service_id, :occurred_at],
    message: "a déjà une séance prévue à cette heure-là avec ce service."
  }

  # Custom validations (only on create):
  # - Checks that the service is active for the date of the session
  validate :service_is_active, on: :create
  # - Checks that booking the session does not exceed paid/free quotas
  validate :respect_quota_limits, on: :create
  # - Checks that the service is not cancelled and is within the booking window (today-based)
  validate :service_not_cancelled, on: :create
  # - Checks that an admin has set the service's allocation
  validate :allocation_defined, on: :create
  validate :service_present_in_fliip, on: :create
  validate :service_within_booking_window, on: :create
  # - On edit, the same quota check without counting this séance against itself
  validate :respect_quota_limits_on_update, on: :update, if: :usage_changed?

  # Ensures that the chosen service actually belongs to the selected client.
  validate :service_matches_client

  # -----------------------------------------
  # Callbacks
  # -----------------------------------------
  # Before validation on create:
  #   - Determine whether this session is "free" or "paid"
  #   - Set default duration if not provided
  before_validation :set_session_type_and_duration, on: :create

  #   - On edit, choose the type again when presence or duration changed
  before_validation :recalculate_type, on: :update, if: -> { will_save_change_to_present? || will_save_change_to_duration? }

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

  # Séances that took place in a pay period (PayPeriod), Sunday to Saturday.
  scope :in_period, ->(period) {
    where(occurred_at: period.starts_on.beginning_of_day..period.ends_on.end_of_day)
  }

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

  # The séance's outcome (GLOSSARY.md): Présent·e when the client was present,
  # -24h when absent with no absence left, Absence when an absence was used.
  OUTCOME_LABELS = { chargee: "Présent·e", moins24: "-24h", absence: "Absence" }.freeze

  def outcome
    return :absence if free?

    present ? :chargee : :moins24
  end

  def outcome_label
    OUTCOME_LABELS.fetch(outcome)
  end

  # « 1 h », « 30 min », « 1 h 30 ».
  def duration_short
    hours, minutes = (duration.to_f * 60).round.divmod(60)
    return "#{minutes} min" if hours.zero?

    minutes.zero? ? "#{hours} h" : "#{hours} h #{minutes}"
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

  # Each séance's number in its service ({ id => number }), as
  # FliipService#numbered_sessions counts it, for a list that mixes services:
  # one query ranks the séances of their services, one reads the adjustments.
  def self.numbers_for(sessions)
    sessions = sessions.to_a
    return {} if sessions.empty?

    service_ids = sessions.map(&:fliip_service_id).uniq
    ranked = where(fliip_service_id: service_ids)
               .select(:id, Arel.sql("ROW_NUMBER() OVER (PARTITION BY fliip_service_id ORDER BY occurred_at, id) AS position"))
    positions = unscoped.from(ranked, :ranked).where(ranked: { id: sessions.map(&:id) })
                        .pluck(Arel.sql("ranked.id"), Arel.sql("ranked.position")).to_h
    adjustments = ServiceUsageAdjustment.where(fliip_service_id: service_ids)
                                        .pluck(:fliip_service_id, :created_at, :paid_used_delta, :free_used_delta)
                                        .group_by(&:first)

    sessions.to_h do |session|
      offset = adjustments.fetch(session.fliip_service_id, []).sum do |_, created_at, paid, free|
        session.occurred_at && created_at <= session.occurred_at ? paid.to_f + free.to_f : 0.0
      end
      [ session.id, positions.fetch(session.id) + offset ]
    end
  end

  # Confirms for payroll and records who did it. Idempotent: only touches
  # unconfirmed séances. Returns how many it confirmed.
  def self.confirm(ids, by:)
    ids = Array(ids).map(&:to_i).uniq
    return 0 if ids.empty?

    where(id: ids).unconfirmed.update_all(
      confirmed: true,
      confirmed_at: Time.current,
      confirmed_by_id: by.id
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

  # What the service has left for this séance when it is edited: the absences
  # (or paid séances) remaining, plus what this séance used as last saved.
  def free_left_excluding_self
    fliip_service.remaining_free_sessions.to_f + own_saved_usage("free")
  end

  def paid_left_excluding_self
    fliip_service.remaining_paid_sessions.to_f + own_saved_usage("paid")
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

  # Same rules as on create, with this séance's own usage (as last saved)
  # given back, so it doesn't count against itself.
  def recalculate_type
    self.duration = (duration.presence || 1.0).to_f
    return if fliip_service.nil?

    self.session_type =
      if present || fliip_service.allocation_to_define?
        :paid
      else
        free_left_excluding_self >= duration ? :free : :paid
      end
  end

  def own_saved_usage(type)
    attribute_in_database(:session_type) == type ? attribute_in_database(:duration).to_f : 0.0
  end

  def usage_changed?
    will_save_change_to_session_type? || will_save_change_to_present? || will_save_change_to_duration?
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
    # Without an allocation there is nothing to count (allocation_defined says why).
    return if fliip_service.allocation_to_define?

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

  def respect_quota_limits_on_update
    return if fliip_service.blank? || fliip_service.allocation_to_define?

    if paid? && paid_left_excluding_self < duration.to_f
      errors.add(:base, "Aucune séance payante disponible pour ce service.")
    elsif free? && free_left_excluding_self < duration.to_f
      errors.add(:base, "Aucune absence gratuite disponible pour ce service.")
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

  # Prevents booking on a service (or client) Fliip no longer returns.
  def service_present_in_fliip
    return if fliip_service.blank?
    if fliip_service.removed_from_fliip?
      errors.add(:base, "Ce service a été retiré de Fliip. Impossible de créer une séance.")
    end
  end

  # Prevents booking until an admin sets the allocation (« à définir »).
  def allocation_defined
    return if fliip_service.blank?
    if fliip_service.allocation_to_define?
      errors.add(:base, "L'allocation de ce service est à définir.")
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
