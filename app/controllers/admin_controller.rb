class AdminController < ApplicationController
  require "csv"
  before_action :authenticate_user!
  before_action :ensure_admin!

  def dashboard
    # Staff list (order by role then name)
    @users = User.order(role: :desc, last_name: :asc, first_name: :asc)

    # Per-user unconfirmed session counts (include nil as unconfirmed)
    @unconfirmed_counts = Session
      .where(confirmed: [false, nil])
      .group(:user_id)
      .count

    # Distinct services touched per user (sessions or adjustments)
    # (kept simple & readable; can optimize with a SQL UNION later if needed)
    sessions_pairs = Session.distinct.pluck(:user_id, :fliip_service_id)
    adjust_pairs   = ServiceUsageAdjustment.distinct.pluck(:user_id, :fliip_service_id)

    tmp = Hash.new { |h, k| h[k] = [] }
    sessions_pairs.each { |uid, sid| tmp[uid] << sid }
    adjust_pairs.each { |uid, sid| tmp[uid] << sid }

    @services_touched_counts = tmp.transform_values { |arr| arr.uniq.size }

    # Signup codes (small slice to keep dashboard light)
    @signup_codes = SignupCode.order(created_at: :desc).limit(20)

    # Services ending soon (next 30 days) and ended recently (last 30 days)
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

  def unconfirmed_sessions
    @sessions = Session.where(confirmed: [false, nil])
                      .includes(:fliip_user, :fliip_service, :user)
                      .order(date: :desc, time: :desc)

    @staff = User.active.order(:last_name, :first_name) # for reassign dropdown
  end

  def confirm_sessions
    session_ids = params[:session_ids] || []
    confirmed = Session.where(id: session_ids).update_all(confirmed: true)
    redirect_to admin_unconfirmed_sessions_path,
                notice: "#{confirmed} #{'session'.pluralize(confirmed)} confirmed."
  end

  def import_clients
    FliipApi::UserSync::UserImporter.call
    redirect_to new_session_path, notice: "Client list refreshed."
    rescue => e
      redirect_to new_session_path, alert: "Could not refresh clients: #{e.message}"
  end

  def client_services
    services = FliipService
      .includes(:fliip_user, :service_definition)
      .order(:fliip_user_id, :service_name)

    service_ids = services.map(&:id)

    # Sessions usage (sum of duration) by service + type
    session_sums = Session
      .where(fliip_service_id: service_ids)
      .group(:fliip_service_id, :session_type)
      .sum(:duration) # { [id,"paid"]=>7.5, [id,"free"]=>2.0 }

    # Adjustments: sum deltas by service
    adj_paid = ServiceUsageAdjustment
      .where(fliip_service_id: service_ids)
      .group(:fliip_service_id)
      .sum(:paid_used_delta)   # { id => 1.0 }

    adj_free = ServiceUsageAdjustment
      .where(fliip_service_id: service_ids)
      .group(:fliip_service_id)
      .sum(:free_used_delta)   # { id => 0.5 }

    headers = %w[
      client_id
      client_remote_id
      client_name
      service_id
      service_remote_purchase_id
      service_name
      purchase_status
      start_date
      expire_date
      paid_used
      paid_included
      free_used
      free_included
    ]

    csv_str = CSV.generate(headers: true) do |csv|
      csv << headers

      services.each do |svc|
        user = svc.fliip_user
        defn = svc.service_definition

        paid_used = session_sums.fetch([svc.id, "paid"], 0.0).to_f + adj_paid.fetch(svc.id, 0.0).to_f
        free_used = session_sums.fetch([svc.id, "free"], 0.0).to_f + adj_free.fetch(svc.id, 0.0).to_f

        csv << [
          user&.id,
          user&.remote_id,
          [user&.user_firstname, user&.user_lastname].compact.join(" "),
          svc.id,
          svc.remote_purchase_id,
          svc.service_name,
          svc.purchase_status, # A/I/P/C/S
          fmt_date(svc.start_date),
          fmt_date(svc.expire_date),
          paid_used,
          defn&.paid_sessions,
          free_used,
          defn&.free_sessions
        ]
      end
    end

    filename = "clients_services_#{Time.current.strftime('%Y%m%d-%H%M%S')}.csv"
    send_data csv_str, filename:, type: "text/csv"
  end

  def adjustments_new
    @users_for_select = User.order(:first_name, :last_name) # pick any staff member (employee/manager/admin)
  end

  def adjustments_preview
    unless params[:csv].respond_to?(:read)
      redirect_to admin_adjustments_new_path, alert: "Please choose a CSV file." and return
    end

    require "csv"

    @adjustments = []
    CSV.foreach(params[:csv], headers: :first_row, header_converters: :symbol) do |row|
      hashed_row = row.to_hash
      hashed_row[:row_number] = @adjustments.count + 2
      hashed_row[:bonus_sessions] = 0.0 if hashed_row[:bonus_sessions].nil?
      hashed_row[:paid_used] = hashed_row[:paid_used].to_f
      hashed_row[:free_used] = hashed_row[:free_used].to_f
      hashed_row[:bonus_sessions] = hashed_row[:bonus_sessions].to_f
      @adjustments << hashed_row
    end

    @payload_json = { rows: @adjustments }.to_json

    @users_for_select = User.order(:first_name, :last_name)
  end

  # --- Commit to DB ---
  def adjustments_commit
    payload = JSON.parse(params[:payload].to_s) rescue nil

    unless payload && payload["rows"].is_a?(Array)
      redirect_to admin_adjustments_new_path, alert: "Invalid or missing import payload." and return
    end

    employee_id = params[:employee_id]
    created = 0

    payload["rows"].each do |row|
      ServiceUsageAdjustment.create!(
        fliip_service_id: row["service_id"].to_i,
        user_id: employee_id.to_i,
        paid_used_delta: row["paid_used"].to_f,
        free_used_delta: row["free_used"].to_f,
        bonus_sessions: row["bonus_sessions"].to_f
      )
      created += 1
    end

    redirect_to admin_dashboard_path, notice: "Adjustments imported: #{created} created"
  end

  private

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
