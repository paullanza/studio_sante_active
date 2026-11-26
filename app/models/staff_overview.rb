# What a manager sees at a glance on « Personnel », for a list of staff: each
# person's activity in a pay period, their 8-week séance trend, their active
# clients and upcoming renewals, and the flags that say who needs following up
# (« À suivre »). A plain object, not stored: a fixed number of grouped queries
# whatever the number of staff.
#
# Flags only concern people who usually log séances (REGULAR_MIN_PER_WEEK on
# average over the trend), so staff who don't train are never flagged.
# Nothing here knows about vacations: someone on leave is flagged too.
class StaffOverview
  TREND_WEEKS = 8
  RECENT_WEEKS = 2
  # No séance for more than this many days.
  INACTIVE_AFTER_DAYS = 7
  # The last RECENT_WEEKS average under this share of the weeks before.
  FALLING_RATIO = 0.7
  REGULAR_MIN_PER_WEEK = 2
  RENEWAL_WINDOW = 30.days

  Row = Data.define(:user, :chargees, :absences, :moins24, :hours, :consultations, :sales,
                    :clients, :renewals, :last_session_at, :unconfirmed, :trend) do
    def sessions = chargees + absences + moins24

    def days_since_last(today = Date.current)
      last_session_at && (today - last_session_at.to_date).to_i
    end

    # Séances per week on average over the whole trend.
    def regular?
      trend.sum.to_f / trend.size >= REGULAR_MIN_PER_WEEK
    end

    def inactive?(today = Date.current)
      regular? && (days_since_last(today).nil? || days_since_last(today) > INACTIVE_AFTER_DAYS)
    end

    def falling?
      recent = trend.last(RECENT_WEEKS)
      before = trend.first(trend.size - RECENT_WEEKS)
      before_avg = before.sum.to_f / before.size
      before_avg >= REGULAR_MIN_PER_WEEK && recent.sum.to_f / recent.size < before_avg * FALLING_RATIO
    end

    # « 12 → 4 / sem. »: the weeks before against the last ones, rounded.
    def falling_label
      before = trend.first(trend.size - RECENT_WEEKS)
      recent = trend.last(RECENT_WEEKS)
      "#{(before.sum.to_f / before.size).round} → #{(recent.sum.to_f / recent.size).round} / sem."
    end
  end

  attr_reader :period, :today

  def initialize(users, period, today: Date.current)
    @users = users.to_a
    @period = period
    @today = today
  end

  def rows
    @rows ||= @users.map { |user| row_for(user) }
  end

  def row(user)
    rows.find { |r| r.user == user }
  end

  # The team's totals for the period, over the listed staff.
  def totals
    { sessions: rows.sum(&:sessions), hours: rows.sum(&:hours), consultations: rows.sum(&:consultations) }
  end

  # « À suivre »: the four kinds of flag, each with the people it concerns,
  # biggest first. Kinds with nobody are kept, so the band keeps its shape.
  def alerts
    {
      renewals: rows.select { |r| r.renewals.positive? }.sort_by { |r| -r.renewals },
      inactive: rows.select { |r| r.inactive?(today) }.sort_by { |r| -(r.days_since_last(today) || Float::INFINITY) },
      falling: rows.select(&:falling?),
      unconfirmed: rows.select { |r| r.unconfirmed.positive? }.sort_by { |r| -r.unconfirmed }
    }
  end

  # The week starts of the trend, oldest first (Monday weeks, as Postgres counts them).
  def trend_weeks
    current = today.beginning_of_week
    Array.new(TREND_WEEKS) { |i| current - (TREND_WEEKS - 1 - i).weeks }
  end

  # The active services a staff member works on that end within the renewal
  # window, soonest first (the Activité tab lists them).
  def self.renewing_services(user, today: Date.current)
    FliipService.worked_on_by(user).active.where(expire_date: today..(today + RENEWAL_WINDOW))
                .includes(:fliip_user).order(:expire_date)
  end

  private

  def ids
    @ids ||= @users.map(&:id)
  end

  def row_for(user)
    id = user.id
    Row.new(
      user: user,
      chargees: outcomes.fetch([ id, :chargee ], 0),
      absences: outcomes.fetch([ id, :absence ], 0),
      moins24: outcomes.fetch([ id, :moins24 ], 0),
      hours: hours.fetch(id, 0).to_f,
      consultations: consultations.fetch(id, 0),
      sales: sales.fetch(id, 0),
      clients: active_services.fetch(id, []).map(&:fliip_user_id).uniq.size,
      renewals: active_services.fetch(id, []).count { |s| s.expire_date && s.expire_date.between?(today, today + RENEWAL_WINDOW) },
      last_session_at: last_sessions[id],
      unconfirmed: unconfirmed_sessions.fetch(id, 0) + unconfirmed_consultations.fetch(id, 0),
      trend: trend_weeks.map { |week| weekly.fetch([ id, week ], 0) }
    )
  end

  def period_times
    period.starts_on.beginning_of_day..period.ends_on.end_of_day
  end

  def period_sessions
    Session.where(user_id: ids, occurred_at: period_times)
  end

  # { [user id, outcome] => count }, outcomes as Session#outcome names them.
  def outcomes
    @outcomes ||= period_sessions.group(:user_id, :session_type, :present).count.each_with_object(Hash.new(0)) do |((uid, type, present), n), acc|
      outcome = type == "free" ? :absence : (present ? :chargee : :moins24)
      acc[[ uid, outcome ]] += n
    end
  end

  def hours
    @hours ||= period_sessions.group(:user_id).sum(:duration)
  end

  def period_consultations
    Consultation.where(user_id: ids, occurred_at: period_times)
  end

  def consultations
    @consultations ||= period_consultations.group(:user_id).count
  end

  # Consultations of the period linked to a service: a sale.
  def sales
    @sales ||= period_consultations.where.not(fliip_service_id: nil).group(:user_id).count
  end

  # { user id => [active services they work on] }: a séance or an adjustment
  # attributed to them, as Mes services counts it.
  def active_services
    @active_services ||= begin
      pairs = (Session.where(user_id: ids).distinct.pluck(:user_id, :fliip_service_id) +
               ServiceUsageAdjustment.where(user_id: ids).distinct.pluck(:user_id, :fliip_service_id)).uniq
      services = FliipService.active.where(id: pairs.map(&:last)).select(:id, :fliip_user_id, :expire_date).index_by(&:id)
      pairs.each_with_object(Hash.new { |h, k| h[k] = [] }) do |(uid, sid), acc|
        acc[uid] << services[sid] if services[sid]
      end
    end
  end

  def last_sessions
    @last_sessions ||= Session.where(user_id: ids, occurred_at: ..Time.current).group(:user_id).maximum(:occurred_at)
  end

  def unconfirmed_sessions
    @unconfirmed_sessions ||= Session.unconfirmed.where(user_id: ids).group(:user_id).count
  end

  def unconfirmed_consultations
    @unconfirmed_consultations ||= Consultation.unconfirmed.where(user_id: ids).group(:user_id).count
  end

  # { [user id, Monday of the week] => séances }.
  def weekly
    @weekly ||= begin
      from = trend_weeks.first.beginning_of_day
      Session.where(user_id: ids, occurred_at: from..today.end_of_day)
             .group(:user_id, Arel.sql(ActiveRecord::Base.sanitize_sql_array(
               [ "DATE_TRUNC('week', occurred_at AT TIME ZONE 'UTC' AT TIME ZONE ?)::date", Time.zone.tzinfo.identifier ]
             )))
             .count
             .transform_keys { |(uid, week)| [ uid, week.to_date ] }
    end
  end
end
