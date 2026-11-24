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

    @signup_codes = SignupCode.order(created_at: :desc).limit(20)

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

  def create_signup_code
    SignupCode.create!
    redirect_to admin_dashboard_path, notice: "Signup code generated."
  end

  def deactivate_signup_code
    code = SignupCode.find(params[:id])

    if code.safely_deactivate!
      redirect_to admin_dashboard_path, notice: "Signup code deactivated."
    else
      redirect_to admin_dashboard_path, alert: "Cannot deactivate an expired or used code."
    end
  end

  # Unconfirmed Sessions
  def unconfirmed_sessions
    @filter_params = permitted_session_filters
    @sessions = Session.unconfirmed
                       .apply_filters(@filter_params)
                       .with_associations
                       .order_by_occurred_at_asc

    @staff = User.selectable.order(:first_name, :last_name)
  end

  def confirm_sessions
    ids = Array(params[:session_ids]).map(&:to_i).uniq
    if ids.empty?
      redirect_to admin_unconfirmed_sessions_path, alert: "No sessions selected." and return
    end

    updated = Session.confirm(ids)

    if updated.zero?
      redirect_to admin_unconfirmed_sessions_path, alert: "Nothing to confirm (already confirmed?)."
    else
      redirect_to admin_unconfirmed_sessions_path,
                  notice: "#{updated} #{'session'.pluralize(updated)} confirmed."
    end
  end

  # Unconfirmed Consultations
  def unconfirmed_consultations
    @filter_params = permitted_consultation_filters
    @consultations = Consultation.unconfirmed
                                 .apply_filters(@filter_params)
                                 .with_associations
                                 .order_by_occurred_at_desc

    @staff = User.selectable.order(:first_name, :last_name)
  end

  def confirm_consultations
    ids = Array(params[:consultation_ids]).map(&:to_i).uniq
    if ids.empty?
      redirect_to admin_unconfirmed_consultations_path, alert: "No consultations selected." and return
    end

    updated = Consultation.confirm(ids)

    if updated.zero?
      redirect_to admin_unconfirmed_consultations_path, alert: "Nothing to confirm (already confirmed?)."
    else
      redirect_to admin_unconfirmed_consultations_path,
                  notice: "#{updated} #{'consultation'.pluralize(updated)} confirmed."
    end
  end

  # Runs in the background; a sync already running makes it wait its turn.
  def import_clients
    FliipFullSyncJob.perform_later
    redirect_to admin_dashboard_path, notice: "Synchronisation Fliip lancée en arrière-plan. Suivez-la dans Tâches (/jobs)."
  end

  private

  def permitted_session_filters
    params.permit(
      :q,
      :employee_id,
      :session_date_from, :session_date_to,
      :created_from, :created_to,
      present: [], session_type: []
    )
  end

  def permitted_consultation_filters
    params.permit(
      :q,
      :employee_id,
      :consultation_date_from, :consultation_date_to,
      :created_from, :created_to,
      present: []
    )
  end

  # The query is inferred from the action name.
  def authorize_admin
    authorize :admin
  end

  # Keeps the existing redirect and message for non-admins.
  def user_not_authorized
    redirect_to authenticated_root_path, alert: "Not authorized"
  end
end
