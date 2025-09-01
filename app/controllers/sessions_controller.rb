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
                  .order_by_occurred_at_desc
                  .limit(25)
  end

  def create
    @session = Session.new(session_params)
    @session.user       = chosen_creator_for_create
    @session.created_by = current_user

    # Always assign from parsed date/time
    @session.occurred_at = parsed_occurred_at_from_params

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
    session.created_by_id == current_user.id && !session.confirmed?
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
      :present,
      :note,
      :occurred_at
    )
  end

  def parsed_occurred_at_from_params
    d = params.dig(:session, :date).to_s.strip
    t = params.dig(:session, :time).to_s.strip
    return nil if d.blank? || t.blank?

    begin
      date = Date.parse(d)
      if /\A\d{1,2}:\d{2}\z/ === t
        h, m = t.split(":").map(&:to_i)
        Time.zone.local(date.year, date.month, date.day, h, m)
      else
        Time.zone.parse("#{d} #{t}")
      end
    rescue ArgumentError
      nil
    end
  end

  def session_payload(s)
    {
      id: s.id,
      date: s.occurred_at&.to_date&.strftime("%Y-%m-%d"),
      time: s.occurred_at&.strftime("%H:%M"),
      present: s.present?,
      note: s.note.to_s,
      duration: s.duration.to_f,
      session_type: s.session_type
    }
  end
end
