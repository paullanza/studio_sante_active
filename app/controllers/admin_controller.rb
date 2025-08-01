class AdminController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_admin!

  def dashboard
    SignupCode.active
              .where("expiry_date < ?", Time.current)
              .find_each { |c| c.update!(status: :expired) }

    @users = User.order(:last_name, :first_name)
    @signup_codes = SignupCode.order(created_at: :desc)
  end

  def create_signup_code
    SignupCode.create!
    redirect_to admin_dashboard_path, notice: "Signup code generated."
  end

  def deactivate_signup_code
    code = SignupCode.find(params[:id])

    if code.active? && code.expiry_date.future?
      code.update!(status: :deactivated)
      redirect_to admin_dashboard_path, notice: "Signup code deactivated."
    else
      redirect_to admin_dashboard_path, alert: "Cannot deactivate an expired or used code."
    end
  end

  def services
    @known_services = FliipService
      .select(:service_id, :service_name)
      .distinct
      .order(:service_id)

    @service_definitions = ServiceDefinition.all.index_by(&:service_id)
  end

  def create_service
    ServiceDefinition.create!(service_id: params[:service_id],
                              paid_sessions: params[:paid_sessions],
                              free_sessions: params[:free_sessions])
    redirect_to admin_services_path, notice: "Service definition created."
  end

  def update_service
    definition = ServiceDefinition.find(params[:id])
    definition.update!(paid_sessions: params[:paid_sessions],
                       free_sessions: params[:free_sessions])
    redirect_to admin_services_path, notice: "Service definition updated."
  end


  private

  def ensure_admin!
    redirect_to root_path, alert: "Not authorized" unless current_user.admin?
  end
end
