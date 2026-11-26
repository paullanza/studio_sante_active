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
  # Linked consultations: a service can have several, each links to one service.
  has_many   :consultations, dependent: :restrict_with_error, inverse_of: :fliip_service

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

  # The link window (GLOSSARY.md): bought from 14 days before to 30 days after
  # the consultation, by purchase date, else start date.
  LINK_WINDOW_BEFORE = 14.days
  LINK_WINDOW_AFTER = 30.days
  scope :purchase_within_association_window, ->(base_date) {
    base = (base_date.presence || Date.current).to_date
    where("COALESCE(purchase_date::date, start_date) BETWEEN ? AND ?", base - LINK_WINDOW_BEFORE, base + LINK_WINDOW_AFTER)
  }

  # The client's services a consultation can link to, newest end date first.
  # A service already linked to another consultation stays available.
  scope :available_for_association, ->(fliip_user_id:, base_date: nil) {
    for_fliip_user(fliip_user_id)
      .purchase_within_association_window(base_date)
      .order(expire_date: :desc, service_name: :asc)
  }

  # The date the link window is measured from: purchase date, else start date.
  def link_date
    purchase_date&.to_date || start_date
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
  # Adjustment sums, by kind (ServiceUsageAdjustment)
  # -----------------------------------------
  # Séances and absences added to the allocation.
  def bonus_sessions_total
    adjustment_sum(:paid_bonus)
  end

  def free_bonus_total
    adjustment_sum(:free_bonus)
  end

  # Séances and absences recorded as used.
  def paid_used_adjustment
    adjustment_sum(:paid_used)
  end

  def free_used_adjustment
    adjustment_sum(:free_used)
  end

  # -----------------------------------------
  # Usage Totals (sessions + adjustments)
  # -----------------------------------------
  def paid_used_total
    (@preloaded_usage ? @preloaded_usage[:paid_duration] : paid_sessions.sum(:duration).to_f) + paid_used_adjustment
  end

  def free_used_total
    (@preloaded_usage ? @preloaded_usage[:free_duration] : free_sessions.sum(:duration).to_f) + free_used_adjustment
  end

  # Counts the séances and adjustments of many services in two grouped
  # queries, so a list of them doesn't sum per service. The usage methods
  # above read these sums; a service that wasn't preloaded queries its own.
  # Sums are taken once: call it again after a change to recount.
  def self.preload_usage(services)
    services = services.compact.uniq
    return services if services.empty?

    ids = services.map(&:id)
    durations = Session.where(fliip_service_id: ids).group(:fliip_service_id, :session_type).sum(:duration)
    adjustments = ServiceUsageAdjustment.where(fliip_service_id: ids).group(:fliip_service_id, :kind).sum(:amount)

    services.each do |service|
      service.preloaded_usage = {
        paid_duration: durations[[ service.id, "paid" ]].to_f,
        free_duration: durations[[ service.id, "free" ]].to_f,
        adjustments: ServiceUsageAdjustment.kinds.keys.to_h { |kind| [ kind, adjustments[[ service.id, kind ]].to_f ] }
      }
    end
  end

  # Set by .preload_usage; a reload drops it so the counts come from SQL again.
  attr_writer :preloaded_usage

  def reload(*)
    @preloaded_usage = nil
    super
  end

  # -----------------------------------------
  # Allowed Totals
  # -----------------------------------------
  def paid_allowed_total
    base = service_definition&.paid_sessions.to_f
    base + bonus_sessions_total
  end

  def free_allowed_total
    service_definition&.free_sessions.to_f + free_bonus_total
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
    adjustments = service_usage_adjustments.where(kind: %i[paid_used free_used]).pluck(:created_at, :amount)

    ordered.each_with_index.map do |session, index|
      offset = adjustments.sum do |created_at, amount|
        session.occurred_at && created_at <= session.occurred_at ? amount : 0.0
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

  private

  # One kind's total: from .preload_usage, else from the adjustments already
  # loaded (pages include them), else in SQL. Loaded records count as saved,
  # so an unsaved new or edited one doesn't move the totals.
  def adjustment_sum(kind)
    return @preloaded_usage[:adjustments][kind.to_s] if @preloaded_usage

    if service_usage_adjustments.loaded?
      saved = service_usage_adjustments.select { |a| a.persisted? && a.kind_in_database == kind.to_s }
      return saved.sum { |a| a.amount_in_database.to_f }
    end

    service_usage_adjustments.where(kind: kind).sum(:amount).to_f
  end
end
