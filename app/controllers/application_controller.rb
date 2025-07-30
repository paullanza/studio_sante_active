class ApplicationController < ActionController::Base
  before_action :configure_permitted_parameters, if: :devise_controller?

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
