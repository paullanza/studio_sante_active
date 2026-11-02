class BookingsController < ApplicationController
  before_action :authenticate_user!
  before_action :load_staff
  after_action :verify_authorized

  def new
    authorize :booking

    @active_tab = %w[session consultation].include?(params[:tab]) ? params[:tab] : "session"

    # Forms
    @session       = Session.new
    @consultation  = Consultation.new

    # Session-side helpers (client search + services)
    load_fliip_users
    if params[:fliip_user_id].present?
      @session.fliip_user_id = params[:fliip_user_id]
      @services = FliipService
                    .where(fliip_user_id: params[:fliip_user_id])
                    .includes(:fliip_user, :service_definition, :service_usage_adjustments)
                    .order(:expire_date, :service_name)
    else
      @services = []
    end

    # Right-side tables
    @sessions = Session
                  .where(user_id: current_user.id)
                  .unconfirmed
                  .with_associations
                  .order_by_occurred_at_desc
                  .limit(25)

    @consultations = Consultation
                       .unconfirmed
                       .by_employee(current_user.id)
                       .order_by_occurred_at_desc
                       .includes(:user)
                       .limit(25)
  end

  private

  # Matches SessionsController#load_staff
  def load_staff
    @staff = policy(Session).change_owner? ? User.selectable.order(:first_name, :last_name) : []
    # The super admin is not selectable, so must pick an employee.
    @owner_required = @staff.any? && @staff.none? { |u| u.id == current_user.id }
  end

  # Matches SessionsController#load_fliip_users to keep UX consistent
  def load_fliip_users
    service_user_ids = FliipService.distinct.pluck(:fliip_user_id)
    @fliip_users = FliipUser
      .where(id: service_user_ids)
      .sort_by do |u|
        I18n.transliterate("#{u.user_lastname.to_s.strip} #{u.user_firstname.to_s.strip}").downcase
      end
  end
end
