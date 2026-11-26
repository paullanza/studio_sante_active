# « Confirmations » (admins): before payroll, an admin checks each séance and
# consultation of a pay period against the signature sheet and confirms it.
# Each tab lists the period's unconfirmed records by trainer; confirmed ones
# leave the list.
class ConfirmationsController < ApplicationController
  before_action :authenticate_user!
  before_action :load_period_and_filters, only: [ :sessions, :consultations ]
  layout "studio"

  def sessions
    authorize :admin, :session_confirmations?

    @groups = grouped_by_trainer(Session.in_period(@period).unconfirmed.apply_filters(@filter_params).with_associations)
    listed = @groups.flat_map(&:last)
    FliipService.preload_usage(listed.map(&:fliip_service))
    @numbers = Session.numbers_for(listed)

    @earlier = earlier_unconfirmed(Session)
  end

  def consultations
    authorize :admin, :consultation_confirmations?

    @groups = grouped_by_trainer(Consultation.in_period(@period).unconfirmed.apply_filters(@filter_params).with_associations)
    @earlier = earlier_unconfirmed(Consultation)
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

  def confirm_consultations
    authorize :admin, :confirm_consultations?

    back = consultation_confirmations_path(params.permit(:periode, :employee_id, :q).to_h)
    ids = Array(params[:consultation_ids]).compact_blank
    return redirect_to back, alert: "Aucune consultation sélectionnée." if ids.empty?

    confirmed = Consultation.confirm(ids, by: current_user)
    if confirmed.zero?
      redirect_to back, alert: "Rien à confirmer : ces consultations sont déjà confirmées."
    else
      redirect_to back, notice: "#{confirmed} consultation(s) confirmée(s)."
    end
  end

  private

  def load_period_and_filters
    @period = PayPeriod.from_param(params[:periode])
    @periods = PayPeriod.recent
    @periods << @period unless @periods.include?(@period)
    @filter_params = { employee_id: params[:employee_id].presence, q: params[:q].presence }
    # A deactivated trainer stays in the list while their filter is on.
    @staff = User.selectable.or(User.where(id: @filter_params[:employee_id])).order(:first_name, :last_name)
  end

  # Grouped by trainer (by name), oldest first in each group.
  def grouped_by_trainer(records)
    records.to_a
           .sort_by { |r| [ r.occurred_at || Time.zone.at(0), r.id ] }
           .group_by(&:user)
           .sort_by { |trainer, _| I18n.transliterate(trainer.full_name.to_s).downcase }
  end

  # Unconfirmed séances or consultations left in earlier periods (with the
  # same filters), and the period of the oldest one, for the notice above the
  # list.
  def earlier_unconfirmed(model)
    earlier = model.unconfirmed.where(occurred_at: ...@period.starts_on.beginning_of_day).apply_filters(@filter_params)
    count = earlier.count
    return if count.zero?

    oldest = earlier.minimum(:occurred_at)
    { count: count, period: PayPeriod.containing(oldest.to_date) }
  end
end
