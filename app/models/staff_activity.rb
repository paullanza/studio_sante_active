# A staff member's activity in one pay period (Personnel → Activité): their
# séances and consultations, oldest first, and the totals over them. A plain
# object, not stored.
class StaffActivity
  Totals = Data.define(:chargees, :absences, :moins24, :hours, :consultations_present, :consultations_absent,
                       :sessions_confirmed, :consultations_confirmed)

  attr_reader :user, :period

  def initialize(user, period)
    @user = user
    @period = period
  end

  def sessions
    @sessions ||= Session.where(user: user, occurred_at: times).with_associations.order(:occurred_at, :id).to_a
  end

  def consultations
    @consultations ||= Consultation.where(user: user, occurred_at: times).with_associations.order(:occurred_at, :id).to_a
  end

  # Séances by outcome (Présent·e, Absence, -24h), the hours they add up to,
  # consultations by presence, and how many of each are confirmed.
  def totals
    outcomes = sessions.map(&:outcome).tally
    Totals.new(
      chargees: outcomes.fetch(:chargee, 0),
      absences: outcomes.fetch(:absence, 0),
      moins24: outcomes.fetch(:moins24, 0),
      hours: sessions.sum { |s| s.duration.to_f },
      consultations_present: consultations.count { |c| c.present == true },
      consultations_absent: consultations.count { |c| c.present == false },
      sessions_confirmed: sessions.count(&:confirmed?),
      consultations_confirmed: consultations.count(&:confirmed?)
    )
  end

  private

  # Sunday 00:00 to Saturday 23:59:59 of the period.
  def times
    period.starts_on.beginning_of_day..period.ends_on.end_of_day
  end
end
