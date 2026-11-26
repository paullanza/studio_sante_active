# Séances and consultations edited or deleted on a staff member's Activité tab
# (context "personnel"): the tab's totals are drawn again, for the period the
# record was listed in.
module StaffActivityStreams
  extend ActiveSupport::Concern

  private

  def personnel_context?
    params[:context] == "personnel"
  end

  def activity_totals_stream(user, time)
    return [] unless user && time

    activity = StaffActivity.new(user, PayPeriod.containing(time.to_date))
    [ turbo_stream.replace(helpers.dom_id(user, :activity_totals), partial: "users/activity_totals", locals: { activity: activity }) ]
  end
end
