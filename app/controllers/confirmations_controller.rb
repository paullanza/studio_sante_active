# « Confirmations » (admins): before payroll, an admin checks each séance of
# a pay period against the signature sheet and confirms it. The page lists
# the period's unconfirmed séances by trainer; confirmed ones leave the list.
class ConfirmationsController < ApplicationController
  before_action :authenticate_user!
  layout "studio"

  def sessions
    authorize :admin, :session_confirmations?

    @period = PayPeriod.from_param(params[:periode])
    @periods = PayPeriod.recent
    @periods << @period unless @periods.include?(@period)
    @filter_params = { employee_id: params[:employee_id].presence, q: params[:q].presence }
    # A deactivated trainer stays in the list while their filter is on.
    @staff = User.selectable.or(User.where(id: @filter_params[:employee_id])).order(:first_name, :last_name)

    sessions = Session.in_period(@period).unconfirmed.apply_filters(@filter_params).with_associations
    # Grouped by trainer (by name), oldest séance first in each group.
    @groups = sessions.to_a
                      .sort_by { |s| [ s.occurred_at || Time.zone.at(0), s.id ] }
                      .group_by(&:user)
                      .sort_by { |trainer, _| I18n.transliterate(trainer.full_name.to_s).downcase }
    listed = @groups.flat_map(&:last)
    FliipService.preload_usage(listed.map(&:fliip_service))
    @numbers = Session.numbers_for(listed)

    @earlier = earlier_unconfirmed
  end

  def confirm_sessions
    authorize :admin, :confirm_sessions?

    back = session_confirmations_path(params.permit(:periode, :employee_id, :q).to_h)
    ids = Array(params[:session_ids]).compact_blank
    return redirect_to back, alert: "Aucune séance sélectionnée." if ids.empty?

    confirmed = Session.confirm(ids, by: current_user)
    if confirmed.zero?
      redirect_to back, alert: "Rien à confirmer : ces séances sont déjà confirmées."
    else
      redirect_to back, notice: "#{confirmed} séance(s) confirmée(s)."
    end
  end

  private

  # Unconfirmed séances left in earlier periods (with the same filters), and
  # the period of the oldest one, for the notice above the list.
  def earlier_unconfirmed
    earlier = Session.unconfirmed.where(occurred_at: ...@period.starts_on.beginning_of_day).apply_filters(@filter_params)
    count = earlier.count
    return if count.zero?

    oldest = earlier.minimum(:occurred_at)
    { count: count, period: PayPeriod.containing(oldest.to_date) }
  end
end
