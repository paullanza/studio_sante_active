class SessionsController < ApplicationController
  include BookingPage

  before_action :authenticate_user!
  before_action :set_session, only: [:destroy, :edit, :update, :row]
  before_action :load_staff,  only: [:edit, :update]

  OWNER_REQUIRED_MESSAGE = "Veuillez choisir un·e employé·e.".freeze

  def create
    authorize Session

    @session = Session.new(permitted_attributes(Session))
    @session.user       = chosen_creator_for_create
    @session.created_by = current_user
    @session.occurred_at = parsed_occurred_at_from_params
    @session.confirmed   = false
    @session.present     = params.dig(:session, :present) == "1"

    if @session.user.present? && @session.save
      redirect_to new_seance_path(fliip_user_id: @session.fliip_user_id), notice: "Séance enregistrée."
    else
      @session.errors.add(:base, OWNER_REQUIRED_MESSAGE) if @session.user.nil?

      prepare_booking_page(client_id: @session.fliip_user_id, tab: "session")
      render "bookings/new", layout: "studio", status: :unprocessable_content
    end
  end

  def edit
    authorize @session
    render partial: "sessions/shared/session_edit_row",
          locals: { session: @session, show_bulk_checkbox: params[:show_bulk].present? },
          layout: false
  end

  def row
    authorize @session
    render partial: "sessions/shared/session_row",
          locals: { session: @session, show_bulk_checkbox: params[:show_bulk].present? },
          layout: false
  end

  def update
    authorize @session

    @session.note        = params.dig(:session, :note).to_s
    @session.present     = params.dig(:session, :present) == "1"
    @session.duration    = (params[:half_hour] == "1") ? 0.5 : 1.0
    @session.occurred_at = parsed_occurred_at_from_params

    uid = permitted_attributes(@session)[:user_id]
    if uid.present? && uid.to_i != @session.user_id
      @session.user = User.selectable.find_by(id: uid)
      @session.created_by = current_user
    end
    @session.send(:set_session_type_and_duration)

    if @session.user.present? && @session.save
      render partial: "sessions/shared/session_row",
            locals: { session: @session, show_bulk_checkbox: params[:show_bulk].present? },
            layout: false
    else
      @session.errors.add(:base, OWNER_REQUIRED_MESSAGE) if @session.user.nil?
      render partial: "sessions/shared/session_edit_row",
            locals: { session: @session, show_bulk_checkbox: params[:show_bulk].present? },
            status: :unprocessable_content,
            layout: false
    end
  end

  def destroy
    authorize @session

    @session.destroy
    respond_to do |format|
      format.json { head :no_content }
      format.html { redirect_back fallback_location: admin_unconfirmed_sessions_path, notice: "Séance supprimée." }
    end
  end

  def refresh_clients
    authorize Session

    summary = FliipApi::NewClients.new(client: FliipApi::Client.new).call
    redirect_to new_seance_path, notice: new_clients_notice(summary)
  rescue FliipApi::Unavailable => e
    Rails.logger.error("[Fliip] refresh_clients failed: #{e.message}")
    redirect_to new_seance_path, alert: "Fliip ne répond pas, réessayez plus tard."
  end

  private

  def new_clients_notice(summary)
    notice = summary.synced.zero? ? "Aucun·e nouveau·elle client·e dans Fliip." : "#{summary.synced} client·e(s) ajouté·e(s) depuis Fliip."
    summary.failed.any? ? "#{notice} #{summary.failed.size} en échec, réessayez plus tard." : notice
  end

  def load_staff
    @staff = policy(Session).change_owner? ? User.selectable.order(:last_name, :first_name) : []
    # The super admin is not selectable, so must pick an employee.
    @owner_required = @staff.any? && @staff.none? { |u| u.id == current_user.id }
  end

  # Keeps this controller's existing response formats.
  def user_not_authorized
    respond_to do |format|
      format.json { head :forbidden }
      format.html { redirect_back fallback_location: admin_unconfirmed_sessions_path, alert: "Non autorisé·e." }
    end
  end

  # Nil when the owner is not selectable, such as a super admin who left
  # the employee blank.
  def chosen_creator_for_create
    return current_user unless policy(Session).change_owner?

    id = params.dig(:session, :user_id).presence || current_user.id
    User.selectable.find_by(id: id)
  end

  def set_session
    @session = Session.find(params[:id])
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
