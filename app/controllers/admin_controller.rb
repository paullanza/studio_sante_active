class AdminController < ApplicationController
  before_action :authenticate_user!
  before_action :authorize_admin

  def dashboard
    @users = policy_scope(User).order(role: :desc, last_name: :asc, first_name: :asc)

    @unconfirmed_counts = Session
      .where(confirmed: [false, nil])
      .group(:user_id)
      .count

    @unconfirmed_consultation_counts = Consultation
      .where(confirmed: [false, nil])
      .group(:user_id)
      .count

    sessions_pairs = Session.distinct.pluck(:user_id, :fliip_service_id)
    adjust_pairs   = ServiceUsageAdjustment.distinct.pluck(:user_id, :fliip_service_id)

    tmp = Hash.new { |h, k| h[k] = [] }
    sessions_pairs.each { |uid, sid| tmp[uid] << sid }
    adjust_pairs.each { |uid, sid| tmp[uid] << sid }

    @services_touched_counts = tmp.transform_values { |arr| arr.uniq.size }

    today = Date.current
    @services_ending_soon = FliipService
      .active
      .where(expire_date: today..(today + 30.days))
      .includes(:fliip_user, :service_definition, :service_usage_adjustments)
      .order(:expire_date)

    @services_ended_recent = FliipService
      .where(expire_date: (today - 30.days)..(today - 1.day))
      .includes(:fliip_user, :service_definition, :service_usage_adjustments)
      .order(expire_date: :desc)

    @consultations_last_30 = Consultation
      .where(occurred_at: (today - 30.days)..today)
      .order(occurred_at: :desc)
  end

  # Runs in the background; a sync already running makes it wait its turn.
  def import_clients
    FliipFullSyncJob.perform_later
    redirect_to admin_dashboard_path, notice: "Synchronisation Fliip lancée en arrière-plan. Suivez-la dans Tâches (/jobs)."
  end

  private

  # The query is inferred from the action name.
  def authorize_admin
    authorize :admin
  end

  # Keeps the existing redirect and message for non-admins.
  def user_not_authorized
    redirect_to authenticated_root_path, alert: "Not authorized"
  end
end
