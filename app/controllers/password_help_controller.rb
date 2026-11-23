# « Mot de passe oublié? »: the app sends no email, so this page tells staff
# to ask a manager or an admin for a password reset. Public page.
class PasswordHelpController < ApplicationController
  layout "studio"

  def show
    # Public information page with no record to authorize.
    skip_authorization
  end
end
