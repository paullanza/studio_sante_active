class FliipService < ApplicationRecord
  include MissingFromFliip

  # -----------------------------------------
  # Associations
  # -----------------------------------------
  belongs_to :fliip_user, inverse_of: :fliip_services

  validates :remote_purchase_id, presence: true, uniqueness: true
  has_many   :sessions, dependent: :restrict_with_error, inverse_of: :fliip_service
  belongs_to :service_definition,
              primary_key: :service_id,
              foreign_key: :service_id,
              optional: true
  has_many   :service_usage_adjustments, dependent: :destroy, inverse_of: :fliip_service

  # A service can be linked to at most one consultation at a time.
  has_one    :consultation, dependent: :restrict_with_error, inverse_of: :fliip_service

  # -----------------------------------------
  # Scopes: by purchase status
  # -----------------------------------------
  scope :active,    -> { where(purchase_status: "A") }
  scope :inactive,  -> { where(purchase_status: "I") }
  scope :planned,   -> { where(purchase_status: "P") }
  scope :cancelled, -> { where(purchase_status: "C") }
  scope :stopped,   -> { where(purchase_status: "S") }

  scope :by_statuses, ->(statuses) {
    statuses.present? ? where(purchase_status: statuses) : all
  }

  # Mes services: every service with a séance or an adjustment attributed to the staff member.
  scope :worked_on_by, ->(user) {
    where(id: Session.where(user_id: user.id).select(:fliip_service_id))
      .or(where(id: ServiceUsageAdjustment.where(user_id: user.id).select(:fliip_service_id)))
  }

  # Running services first, soonest end date at the top; then services whose
  # end date has passed, most recently ended first (Mes services).
  scope :ending_soonest_first, ->(today = Date.current) {
    order(Arel.sql(sanitize_sql_array([
      "CASE WHEN expire_date < ? THEN 1 ELSE 0 END, " \
      "CASE WHEN expire_date < ? THEN NULL ELSE expire_date END ASC NULLS LAST, " \
      "expire_date DESC",
      today, today
    ])))
  }

  scope :current, -> {
    where(purchase_status: "A")
      .where("start_date IS NULL OR start_date <= ?", Date.current)
      .where("expire_date IS NULL OR expire_date >= ?", Date.current)
  }

  # -----------------------------------------
  # Status mapping (code → readable label)
  # -----------------------------------------
  STATUS_MAP = {
    "A" => "Actif",
    "I" => "Inactif",
    "P" => "Planifié",
    "C" => "Annulé",
    "S" => "Suspendu"
  }

  def status_name
    STATUS_MAP[purchase_status]
  end

  # -----------------------------------------
  # Association-selection helpers
  # -----------------------------------------
  scope :for_fliip_user, ->(fliip_user_id) {
    where(fliip_user_id: fliip_user_id)
  }

  # Historical window used for *session* browsing on the booking page (+3 months).
  scope :start_within_window, ->(base_date) {
    base = (base_date.presence || Date.current).to_date
    from = base - 14.days
    to   = base + 3.months
    where("COALESCE(start_date, purchase_date::date) BETWEEN ? AND ?", from, to)
  }

  scope :unassociated_with_consultation, -> {
    where.not(id: Consultation.where.not(fliip_service_id: nil).select(:fliip_service_id))
  }

  # Association-specific window:
  # Prefer purchase_date; fallback to start_date; allowed = [-14 days, +30 days]
  scope :purchase_within_association_window, ->(base_date) {
    base = (base_date.presence || Date.current).to_date
    from = base - 14.days
    to   = base + 30.days
    where("COALESCE(purchase_date::date, start_date) BETWEEN ? AND ?", from, to)
  }

  # Backward compatible entrypoint for consultations:
  scope :available_for_association, ->(fliip_user_id:, cutoff_date: nil, base_date: nil) {
    base = (base_date.presence || cutoff_date.presence || Date.current).to_date

    for_fliip_user(fliip_user_id)
      .purchase_within_association_window(base)
      .unassociated_with_consultation
      .includes(:fliip_user, :service_definition, :service_usage_adjustments)
      .order(expire_date: :desc, service_name: :asc)
  }

  def self.find_available_for_association(service_id:, fliip_user_id:, cutoff_date:, base_date: nil)
    return nil if service_id.blank? || fliip_user_id.blank?

    base = (base_date.presence || cutoff_date.presence || Date.current).to_date

    available_for_association(
      fliip_user_id: fliip_user_id,
      base_date:     base
    ).find_by(id: service_id)
  end

  def start_or_purchase_date
    start_date || purchase_date&.to_date
  end

  # -----------------------------------------
  # Convenience Scopes / Collections
  # -----------------------------------------
  def confirmed_sessions
    sessions.confirmed
  end

  def paid_sessions
    sessions.paid
  end

  def free_sessions
    sessions.free
  end

  # -----------------------------------------
  # Adjustment sums (converted to float for safety)
  # -----------------------------------------
  def bonus_sessions_total
    service_usage_adjustments.sum(:bonus_sessions).to_f
  end

  def paid_used_adjustment
    service_usage_adjustments.sum(:paid_used_delta).to_f
  end

  def free_used_adjustment
    service_usage_adjustments.sum(:free_used_delta).to_f
  end

  # -----------------------------------------
  # Usage Totals (sessions + adjustments)
  # -----------------------------------------
  def paid_used_total
    paid_sessions.sum(:duration).to_f + paid_used_adjustment
  end

  def free_used_total
    free_sessions.sum(:duration).to_f + free_used_adjustment
  end

  # -----------------------------------------
  # Allowed Totals
  # -----------------------------------------
  def paid_allowed_total
    base = service_definition&.paid_sessions.to_f
    base + bonus_sessions_total
  end

  def free_allowed_total
    service_definition&.free_sessions.to_f
  end

  # -----------------------------------------
  # Remaining Sessions (clamped to 0.0)
  # -----------------------------------------
  def remaining_paid_sessions
    total = paid_allowed_total
    return nil if total.zero? && service_definition.nil?
    [total - paid_used_total, 0.0].max
  end

  def remaining_free_sessions
    total = free_allowed_total
    return nil if total.zero? && service_definition.nil?
    [total - free_used_total, 0.0].max
  end

  # -----------------------------------------
  # Usage Statistics (compact hash for views/API)
  # -----------------------------------------
  def usage_stats
    {
      paid: {
        used_sessions:  paid_used_total,
        included:       service_definition&.paid_sessions,
        bonus:          bonus_sessions_total,
        allowed_total:  paid_allowed_total,
        remaining:      remaining_paid_sessions
      },
      free: {
        used_sessions:  free_used_total,
        included:       service_definition&.free_sessions,
        allowed_total:  free_allowed_total,
        remaining:      remaining_free_sessions
      }
    }
  end

  # -----------------------------------------
  # Booking Logic
  # -----------------------------------------
  def next_session_type
    return "free" if remaining_free_sessions.to_f > 0.0
    return "paid" if remaining_paid_sessions.to_f > 0.0
    nil
  end

  def can_book_session?
    next_session_type.present?
  end

  # -----------------------------------------
  # Progress Percentages
  # -----------------------------------------
  def paid_progress_percent
    total = paid_allowed_total
    return nil if total.to_f <= 0.0
    ((paid_used_total / total) * 100).round
  end

  def free_progress_percent
    total = free_allowed_total
    return nil if total.to_f <= 0.0
    ((free_used_total / total) * 100).round
  end

  # --- Time window progress (date-based) ---
  def time_progress_percent(today: Date.current)
    return nil if start_date.blank? || expire_date.blank? || expire_date < start_date

    total_days = (expire_date - start_date).to_f
    return nil if total_days <= 0.0

    elapsed = (today - start_date).to_f
    pct     = ((elapsed / total_days) * 100).clamp(0.0, 100.0)
    pct.round
  end

  # Overrun (GLOSSARY.md): the days the end date runs past the planned end,
  # start date + the planned length in months. Up to 2 days past is how the
  # calendar falls, not an overrun.
  OVERRUN_TOLERANCE_DAYS = 2

  # The planned length in months: Fliip's duration (« 12 Mois »), else
  # « N mois » in the service name (duration « Indéfini »). Nil when unknown.
  def planned_months
    months = duration.to_s[/\A\s*(\d+)\s*mois/i, 1] || service_name.to_s[/(\d+)\s*mois/i, 1]
    months.to_i if months.to_i.positive?
  end

  def overrun_days
    months = planned_months
    return nil if months.nil? || start_date.blank? || expire_date.blank?

    days = (expire_date - (start_date >> months)).to_i
    days if days > OVERRUN_TOLERANCE_DAYS
  end

  def overrun_label
    days = overrun_days
    "#{planned_months} mois + #{days} j" if days
  end

  # Days until the end date, floored at 0; nil without an end date.
  def days_left(today = Date.current)
    return nil if expire_date.blank?

    [ (expire_date - today).to_i, 0 ].max
  end

  # The allocation hasn't been set yet: no definition, or one « à définir ».
  # 0/0 is a real allocation. Every page asks this method rather than
  # checking the counts itself.
  def allocation_to_define?
    service_definition.nil? || service_definition.to_define?
  end

  def time_range_label
    return "—" if start_date.blank? || expire_date.blank?
    "#{start_date.strftime('%d/%m/%Y')} – #{expire_date.strftime('%d/%m/%Y')}"
  end

  def paid_breakdown
    used  = paid_used_total.to_f
    base  = service_definition&.paid_sessions
    bonus = bonus_sessions_total.to_f
    allow = paid_allowed_total.to_f
    pct   = paid_progress_percent

    {
      used: used, included: base, bonus: bonus, allowed: allow, percent: pct,
      used_str: format('%.1f', used),
      included_str: base.nil? ? "—" : base.to_s,
      bonus_str: format('%.1f', bonus),
      allowed_str: allow.positive? ? format('%.1f', allow) : "—",
      percent_str: pct.nil? ? "—" : pct.to_s
    }
  end

  def paid_usage_compact_str
    used  = paid_used_total.to_f
    base  = service_definition&.paid_sessions.to_f
    bonus = bonus_sessions_total.to_f

    used_str  = format('%.1f', used)
    base_str  = format('%.1f', base)
    bonus_str = format('%.1f', bonus)

    if bonus.positive?
      "#{used_str}/(#{base_str} + #{bonus_str})"
    else
      "#{used_str}/#{base_str}"
    end
  end

  def absences_compact_str
    "[#{format('%.1f', free_used_total)}/#{free_allowed_total} absences]"
  end

  # The service's séances, oldest first, each with its number, returned newest
  # first: [[session, number], …]. The number is the séance's position among all
  # of this service's séances (every outcome counts), plus the séances and
  # absences that adjustments created at or before it recorded as used (imported
  # clients started mid-service, see docs/adr/0002). Two queries, then Ruby.
  def numbered_sessions
    ordered = sessions.order(:occurred_at, :id).to_a
    adjustments = service_usage_adjustments.pluck(:created_at, :paid_used_delta, :free_used_delta)

    ordered.each_with_index.map do |session, index|
      offset = adjustments.sum do |created_at, paid, free|
        session.occurred_at && created_at <= session.occurred_at ? paid.to_f + free.to_f : 0.0
      end
      [ session, index + 1 + offset ]
    end.reverse
  end

  # -----------------------------------------
  # Booking constraints helpers
  # -----------------------------------------
  def cancelled?
    purchase_status == "C"
  end

  def starts_too_far_in_future?(reference_date = Date.current)
    return false if start_date.blank?
    start_date > (reference_date + 30.days)
  end

  def ended_too_long_ago?(reference_date = Date.current)
    return false if expire_date.blank?
    expire_date < (reference_date - 30.days)
  end

  def fully_used?
    paid_used_total >= paid_allowed_total
  end

  # The service, or its client, is no longer in Fliip.
  def removed_from_fliip?
    missing_from_fliip? || fliip_user&.missing_from_fliip? || false
  end

  def booking_block_reason(reference_date = Date.current)
    return "Retiré de Fliip" if removed_from_fliip?
    return "Annulé" if cancelled?
    return "Allocation à définir" if allocation_to_define?
    return "Commence dans plus de 30 jours" if starts_too_far_in_future?(reference_date)
    return "Terminé il y a plus de 30 jours" if ended_too_long_ago?(reference_date)
    return "Toutes les séances utilisées" if fully_used?
    nil
  end

  def booking_blocked?(reference_date = Date.current)
    booking_block_reason(reference_date).present?
  end
end
