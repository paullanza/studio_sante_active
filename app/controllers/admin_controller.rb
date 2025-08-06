class AdminController < ApplicationController
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

  private

  def ensure_admin!
    redirect_to root_path, alert: "Not authorized" unless current_user.admin?
  end
end
