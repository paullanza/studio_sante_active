# Pages managers and above use to follow up on clients and staff.
class OversightController < ApplicationController
  before_action :authenticate_user!
  layout "studio"

  ECHEANCES_TABS = %w[bientot recents].freeze

  # Services ending in the next 30 days, and those that ended in the last 30,
  # for renewal follow-up.
  def echeances
    authorize :oversight, :echeances?

    @tab = ECHEANCES_TABS.include?(params[:tab]) ? params[:tab] : "bientot"

    today = Date.current
    ending_soon = FliipService.active.where(expire_date: today..(today + 30.days)).order(:expire_date)
    ended_recently = FliipService.where(expire_date: (today - 30.days)..(today - 1.day)).order(expire_date: :desc)
    @counts = { "bientot" => ending_soon.count, "recents" => ended_recently.count }

    # Only the open tab's services are loaded; the other tab shows its count.
    @services = (@tab == "recents" ? ended_recently : ending_soon)
      .includes(:fliip_user, :service_definition, :service_usage_adjustments)
      .to_a
    @trainers_by_service_id = trainer_names_by_service_id(@services)
  end

  # The latest séances across the studio, 50 at a time, newest first;
  # « Voir plus » is the next page. Future séances are left out.
  def recent_sessions
    authorize :oversight, :recent_sessions?

    @employee_id = params[:employee_id].presence
    # A deactivated trainer stays in the list while their filter is on.
    @trainers = User.selectable.or(User.where(id: @employee_id)).order(:first_name, :last_name)

    sessions = Session.where(occurred_at: ..Time.current)
      .by_employee(@employee_id)
      .includes(:user, :fliip_user, :fliip_service)
      .order_by_occurred_at_desc
      .order(id: :desc)
    # Countless: no COUNT query; it only checks whether a next page exists.
    @pagy, @sessions = pagy(:countless, sessions, limit: 50)
  end

  private

  # Staff who logged a séance or an adjustment on each service, by name.
  def trainer_names_by_service_id(services)
    ids = services.map(&:id)
    pairs = Session.where(fliip_service_id: ids).distinct.pluck(:fliip_service_id, :user_id) +
            services.flat_map { |s| s.service_usage_adjustments.map { |a| [ s.id, a.user_id ] } }
    pairs.uniq!

    names = User.where(id: pairs.map(&:last).compact.uniq).to_h { |u| [ u.id, u.full_name ] }
    pairs.each_with_object(Hash.new { |h, k| h[k] = [] }) do |(service_id, user_id), by_service|
      name = names[user_id]
      by_service[service_id] << name if name.present?
    end.transform_values { |list| list.uniq.sort }
  end
end
