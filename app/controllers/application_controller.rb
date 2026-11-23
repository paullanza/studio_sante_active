class ApplicationController < ActionController::Base
  include Pagy::Method
  include Pundit::Authorization

  before_action :configure_permitted_parameters, if: :devise_controller?
  before_action :logout_if_inactive
  # Every action must authorize or explicitly skip_authorization.
  after_action :verify_authorized, unless: :devise_controller?

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  # Devise pages are on the new layout; every other controller opts in with
  # its own `layout "studio"` as its page is rebuilt.
  layout :layout_for_request

  def after_sign_in_path_for(resource)
    return super unless resource.is_a?(User)

    case resource.role.to_s
    when "super_admin", "admin"
      admin_dashboard_path
    when "manager"
      manager_dashboard_path
    else
      user_path(resource) # employees → profile only
    end
  end

  protected

  def logout_if_inactive
    return unless user_signed_in?
    return if current_user.active?

    sign_out current_user
    redirect_to new_user_session_path, alert: t("devise.failure.inactive")
  end

  def layout_for_request
    devise_controller? ? "studio" : "application"
  end

  def configure_permitted_parameters
    # Sign-up is the only Devise registration action (see config/routes.rb).
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
  end

  private

  def user_not_authorized
    respond_to do |format|
      format.json { head :forbidden }
      format.any  { redirect_back fallback_location: authenticated_root_path, alert: "Non autorisé·e." }
    end
  end
end
