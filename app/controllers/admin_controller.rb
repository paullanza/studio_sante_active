class AdminController < ApplicationController
  require "csv"
  before_action :authenticate_user!
  before_action :ensure_admin!

  def dashboard
    SignupCode.expire_old_codes!
    @users = User.order(:last_name, :first_name)
    @signup_codes = SignupCode.order(created_at: :desc)
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
    definition.update!(paid_sessions: params[:paid_sessions],
                       free_sessions: params[:free_sessions])
    redirect_to admin_services_path, notice: "Service definition updated."
  end

  def unconfirmed_sessions
    @sessions = Session.unconfirmed
                       .includes(:fliip_user, :fliip_service, :user)
                       .order(:date, :time)
  end

  def confirm_sessions
    session_ids = params[:session_ids] || []
    confirmed = Session.where(id: session_ids).update_all(confirmed: true)

    redirect_to admin_unconfirmed_sessions_path,
                notice: "#{confirmed} session#{'s' unless confirmed == 1} confirmed."
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
      .sum(:duration) # => { [id,"paid"]=>7.5, [id,"free"]=>2.0 }

    # Optional: ledger adjustments if present
    adj_sums =
      if defined?(UsageAdjustment)
        UsageAdjustment
          .where(fliip_service_id: service_ids)
          .group(:fliip_service_id, :kind)
          .sum(:amount) # => { [id,"paid"]=>1.0, [id,"free"]=>0.5 }
      else
        {}
      end

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

        paid_used =
          session_sums.fetch([svc.id, "paid"], 0.0).to_f +
          adj_sums.fetch([svc.id, "paid"], 0.0).to_f

        free_used =
          session_sums.fetch([svc.id, "free"], 0.0).to_f +
          adj_sums.fetch([svc.id, "free"], 0.0).to_f

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

  private

  def fmt_date(d)
    d.present? ? d.strftime("%d/%m/%Y") : nil
  end

  def ensure_admin!
    redirect_to root_path, alert: "Not authorized" unless current_user.admin?
  end
end
