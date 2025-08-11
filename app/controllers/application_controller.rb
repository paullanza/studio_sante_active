class ApplicationController < ActionController::Base
  include Pagy::Backend

  before_action :configure_permitted_parameters, if: :devise_controller?

  def after_sign_in_path_for(resource)
    case resource.role
    when "admin"
      admin_dashboard_path
    when "manager"
      manager_dashboard_path
    else
      employee_dashboard_path
    end
  end

  protected

  def configure_permitted_parameters
    # For sign up
    devise_parameter_sanitizer.permit(
      :sign_up,
      keys: [
        :first_name,
        :last_name,
        :phone,
        :address,
        :birthday,
        :signup_code_token
      ]
    )

    # For account update (no signup_code_token here)
    devise_parameter_sanitizer.permit(
      :account_update,
      keys: [
        :first_name,
        :last_name,
        :phone,
        :address,
        :birthday
      ]
    )
  end
end
