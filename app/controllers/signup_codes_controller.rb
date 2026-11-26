# « Codes d'inscription » (managers and above): the latest codes, newest
# first. A new code shows on top, ready to copy.
class SignupCodesController < ApplicationController
  before_action :authenticate_user!
  layout "studio"

  LIMIT = 50

  def index
    authorize SignupCode

    # Codes past their date show as expired without anyone doing anything.
    SignupCode.expire_old_codes!
    @signup_codes = SignupCode.includes(:used_by).order(created_at: :desc).limit(LIMIT).to_a
    @highlight = @signup_codes.find { |code| code.id.to_s == params[:highlight].to_s && code.usable? }
  end

  def create
    authorize SignupCode

    code = SignupCode.create!
    redirect_to signup_codes_path(highlight: code.id), notice: "Code créé."
  end

  def deactivate
    code = SignupCode.find(params[:id])
    authorize code

    code.safely_deactivate!
    redirect_to signup_codes_path, notice: "Code désactivé."
  end

  private

  # A code already used, expired or deactivated keeps its own message.
  def user_not_authorized(exception)
    if exception.record.is_a?(SignupCode) && policy(SignupCode).index?
      redirect_to signup_codes_path, alert: "Ce code ne peut plus être désactivé."
    else
      super()
    end
  end
end
