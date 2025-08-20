# app/controllers/sessions_controller.rb
class SessionsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_session, only: [:destroy]

  def new
    @session = Session.new
    load_fliip_users
    @staff = User.active.order(:last_name, :first_name) if admin_like?

    @sessions = Session
                  .where(user_id: current_user.id)
                  .unconfirmed
                  .with_associations
                  .order(date: :desc, time: :desc, created_at: :desc)
                  .limit(25)
  end

  def create
    @session = Session.new(session_params)
    @session.user      = chosen_creator_for_create
    @session.confirmed = false
    @session.present   = params[:session][:present] == "1"
    @session.duration  = params[:half_hour] == "1" ? 0.5 : 1.0

    if @session.save
      redirect_to new_session_path, notice: "Session created successfully."
    else
      load_fliip_users
      @staff = User.active.order(:last_name, :first_name) if admin_like?
      flash.now[:alert] = @session.errors.full_messages.to_sentence.presence || "There was a problem creating the session."
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    unless can_modify?(@session, action: :destroy)
      return respond_to do |format|
        format.json { head :forbidden }
        format.html { redirect_back fallback_location: admin_unconfirmed_sessions_path, alert: "Not authorized." }
      end
    end

    @session.destroy
    respond_to do |format|
      format.json { head :no_content }
      format.html { redirect_back fallback_location: admin_unconfirmed_sessions_path, notice: "Session deleted." }
    end
  end

  def services_table
    fliip_user_id = params.require(:fliip_user_id)
    @services = FliipService
                  .where(fliip_user_id: fliip_user_id)
                  .includes(:fliip_user, :service_definition, :service_usage_adjustments)
                  .order(:expire_date, :service_name)

    render :services_table, layout: false
  end

  # Turbo Frame: the <select name="session[fliip_service_id]">, server-rendered
  def service_select
    fliip_user_id = params.require(:fliip_user_id)
    @services = FliipService
                  .where(fliip_user_id: fliip_user_id)
                  .includes(:service_definition, :service_usage_adjustments)
                  .order(:service_name, :expire_date)

    render :service_select, layout: false
  end

  def refresh_clients
    msg = FliipApi::UserSync::NewUserImporter.call
    redirect_to new_session_path, notice: msg
  rescue => e
    redirect_to new_session_path, alert: "Could not refresh clients: #{e.message}"
  end

  private

  def admin_like?
    current_user.admin? || current_user.super_admin?
  end

  def can_modify?(session, action:)
    return true if admin_like?
    # creators may modify only if the session is unconfirmed
    session.user_id == current_user.id && !session.confirmed?
  end

  def chosen_creator_for_create
    return current_user unless admin_like?

    id = params.dig(:session, :user_id).presence
    id ? User.find(id) : current_user
  end

  def set_session
    @session = Session.find(params[:id])
  end

  def load_fliip_users
    service_user_ids = FliipService.distinct.pluck(:fliip_user_id)

    @fliip_users = FliipUser
      .where(id: service_user_ids)
      .sort_by do |u|
        I18n.transliterate("#{u.user_lastname.to_s.strip} #{u.user_firstname.to_s.strip}").downcase
      end
  end

  def session_params
    params.require(:session).permit(
      :fliip_user_id,
      :fliip_service_id,
      :date,
      :time,
      :present,
      :note
    )
  end

  def session_payload(s)
    {
      id: s.id,
      date: s.date&.strftime("%Y-%m-%d"),
      time: s.time&.strftime("%H:%M"),
      present: s.present?,
      note: s.note.to_s,
      duration: s.duration.to_f,
      session_type: s.session_type
    }
  end
end
