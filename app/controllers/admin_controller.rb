class AdminController < ApplicationController
  require "csv"
  before_action :authenticate_user!
  before_action :ensure_admin!

  def dashboard
    if current_user.super_admin?
      @users = User.order(role: :desc, last_name: :asc, first_name: :asc)
    else
      @users = User.where.not(role: :super_admin).order(role: :desc, last_name: :asc, first_name: :asc)
    end

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

    @exportable_services_count = FliipService.count

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

  def services
    @services = ServiceDefinition.order(:service_id).index_by(&:service_id)
  end

  def update_service
    definition = ServiceDefinition.find(params[:id])
    definition.update!(paid_sessions: params[:paid_sessions].to_i,
                       free_sessions: params[:free_sessions].to_i
                      )
    redirect_to admin_services_path, notice: "Service definition updated."
  end

  def service_show
    @definition = ServiceDefinition.find(params[:id])

    @services = FliipService
      .where(service_id: @definition.service_id)
      .includes(:fliip_user, :service_definition, :service_usage_adjustments)
      .order(Arel.sql("expire_date NULLS LAST"), :service_name)

    @active_count = @services.select { |s| s.purchase_status == "A" }.size
    @total_count  = @services.size
  end

  # Unconfirmed Sessions
  def unconfirmed_sessions
    @filter_params = permitted_session_filters
    @sessions = Session.unconfirmed
                       .apply_filters(@filter_params)
                       .with_associations
                       .order_by_occurred_at_desc

    @staff = User.where(active: true).order(:first_name, :last_name)
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

    @staff = User.where(active: true).order(:first_name, :last_name)
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

  def import_clients
    msg = FliipApi::UserSync::UserImporter.call
    redirect_to admin_dashboard_path, notice: msg
  rescue => e
    redirect_to admin_dashboard_path, alert: "Could not refresh clients: #{e.message}"
  end

  def client_services
    csv_str, filename = CsvPorter::Exporter::Services.call
    send_data csv_str, filename:, type: "text/csv"
  end

  def adjustments_new
  end

  def adjustments_preview
    file = params[:csv]
    unless file&.respond_to?(:path)
      redirect_to admin_adjustments_new_path, alert: "Please choose a CSV file." and return
    end

    require "csv"
    @headers = nil
    @rows    = []

    CSV.foreach(file, headers: true) do |row|
      @headers ||= row.headers
      @rows << row
    end

    @payload_json = { rows: @rows.map(&:to_h) }.to_json
    @users_for_select = User.order(:first_name, :last_name)
  rescue => e
    redirect_to admin_adjustments_new_path, alert: "Could not read CSV: #{e.message}"
  end

  def adjustments_commit
    payload = JSON.parse(params[:payload].to_s) rescue nil
    unless payload && payload["rows"].is_a?(Array)
      redirect_to admin_adjustments_new_path, alert: "Invalid or missing import payload." and return
    end

    employee_id = params[:employee_id].presence
    unless employee_id
      redirect_to admin_adjustments_new_path, alert: "Please select an employee." and return
    end

    result = CsvPorter::Importer::Adjustments.call(
      rows: payload["rows"],
      employee_id: employee_id
    )

    if result.success?
      redirect_to admin_dashboard_path, notice: "Adjustments imported: #{result.created} created."
    else
      msg = "Created #{result.created}. #{result.errors.size} error#{'s' unless result.errors.size == 1}."
      redirect_to admin_dashboard_path, alert: msg
    end
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

  def fmt_date(d)
    d.present? ? d.strftime("%d/%m/%Y") : nil
  end

  def ensure_admin!
    redirect_to root_path, alert: "Not authorized" unless current_user.admin? || current_user.super_admin?
  end

  def to_f_or_zero(value)
    s = value.to_s.strip
    return 0.0 if s.blank?
    Float(s)
  rescue ArgumentError
    0.0
  end
end
