class SessionsController < ApplicationController
  include BookingPage

  before_action :authenticate_user!
  before_action :set_session, only: [:destroy, :edit, :update, :row, :unconfirm]
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
      redirect_to new_seance_path, notice: "Séance enregistrée."
    else
      @session.errors.add(:base, OWNER_REQUIRED_MESSAGE) if @session.user.nil?

      prepare_booking_page(client_id: @session.fliip_user_id, tab: "session")
      render "bookings/new", layout: "studio", status: :unprocessable_content
    end
  end

  def edit
    authorize @session
    return render_edit_card if turbo_frame_request?

    render partial: "sessions/shared/session_edit_row",
          locals: { session: @session, show_bulk_checkbox: params[:show_bulk].present? },
          layout: false
  end

  # The séance's card (« Annuler » in the edit card), or the old table row.
  def row
    authorize @session
    return render_frame_card if turbo_frame_request?

    render partial: "sessions/shared/session_row",
          locals: { session: @session, show_bulk_checkbox: params[:show_bulk].present? },
          layout: false
  end

  # Session#recalculate_type picks the outcome again when presence or duration
  # changed. The new pages (Service, Saisir) answer with Turbo Streams; the old
  # admin tables still get their row partials.
  def update
    authorize @session

    @session.note        = params.dig(:session, :note).to_s
    @session.present     = params.dig(:session, :present) == "1"
    @session.duration    = submitted_duration
    @session.occurred_at = parsed_occurred_at_from_params

    uid = permitted_attributes(@session)[:user_id]
    if uid.present? && uid.to_i != @session.user_id
      @session.user = User.selectable.find_by(id: uid)
      @session.created_by = current_user
    end

    saved = @session.user.present? && @session.save
    @session.errors.add(:base, OWNER_REQUIRED_MESSAGE) if @session.user.nil?

    if request.format.turbo_stream?
      return render_edit_card(status: :unprocessable_content) unless saved

      render turbo_stream: refreshed_lists
    elsif saved
      render partial: "sessions/shared/session_row",
            locals: { session: @session, show_bulk_checkbox: params[:show_bulk].present? },
            layout: false
    else
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
      format.turbo_stream { render turbo_stream: refreshed_lists }
      format.json { head :no_content }
      format.html { redirect_back fallback_location: session_confirmations_path, notice: "Séance supprimée." }
    end
  end

  # « Annuler la confirmation » on Confirmations: back to « Non confirmée ».
  def unconfirm
    authorize @session

    @session.unconfirm!
    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.remove(helpers.dom_id(@session, :item)) }
      format.html { redirect_back fallback_location: session_confirmations_path, notice: "Confirmation annulée." }
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

  # Where the séance is shown: Saisir's latest séances, Confirmations, or the
  # Service page.
  def saisir_context?
    params[:context] == "saisir"
  end

  def confirmations_context?
    params[:context] == "confirmations"
  end

  # The new form sends session[duration]; the old table row sends half_hour.
  def submitted_duration
    duration = params.dig(:session, :duration)
    return duration.to_f if duration.present?

    params[:half_hour] == "1" ? 0.5 : 1.0
  end

  def render_edit_card(status: :ok)
    locals = { session: @session, context: params[:context], trainer_id: params[:trainer_id] }
    if request.format.turbo_stream?
      render turbo_stream: turbo_stream.replace(helpers.dom_id(@session), partial: "sessions/edit_card", locals: locals), status: status
    else
      render partial: "sessions/edit_card", locals: locals, status: status
    end
  end

  # The séance's card in its frame: its row on Confirmations, a latest-séance
  # row on Saisir, else the Service page card with its number.
  def render_frame_card
    return render partial: "confirmations/session_frame", locals: { session: @session } if confirmations_context?

    if saisir_context?
      render partial: "sessions/recent_frame", locals: { session: @session, trainer_id: params[:trainer_id] }
    else
      number = @session.fliip_service.numbered_sessions.to_h { |s, n| [ s.id, n ] }.fetch(@session.id)
      render partial: "sessions/card_frame", locals: { session: @session, number: number }
    end
  end

  # After an edit or a delete: the lists, counts and bars that show the séance.
  # A changed date can reorder the Service page's séances and their numbers, so
  # the whole list is drawn again.
  def refreshed_lists
    if confirmations_context?
      return turbo_stream.replace(helpers.dom_id(@session), partial: "confirmations/session_frame", locals: { session: @session })
    end

    if saisir_context?
      trainer = recent_trainer
      return turbo_stream.replace("recent_sessions", partial: "bookings/recent_sessions",
                                                     locals: { trainer: trainer, sessions: latest_sessions_of(trainer) })
    end

    service = FliipService.includes(:service_definition, :service_usage_adjustments).find(@session.fliip_service_id)
    numbered = service.numbered_sessions
    ActiveRecord::Associations::Preloader.new(records: numbered.map(&:first), associations: %i[user created_by]).call
    [
      turbo_stream.replace(helpers.dom_id(service, :summary), partial: "fliip_services/summary", locals: { service: service }),
      turbo_stream.replace(helpers.dom_id(service, :sessions), partial: "fliip_services/sessions", locals: { service: service, numbered_sessions: numbered }),
      turbo_stream.update(helpers.dom_id(service, :sessions_count), numbered.size.to_s)
    ]
  end

  # Saisir lists one trainer's séances: an admin's chosen trainer, else mine.
  def recent_trainer
    chosen = policy(Session).change_owner? && params[:trainer_id].present? ? User.selectable.find_by(id: params[:trainer_id]) : nil
    chosen || current_user
  end

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
      format.turbo_stream { head :forbidden }
      format.json { head :forbidden }
      format.html { redirect_back fallback_location: session_confirmations_path, alert: "Non autorisé·e." }
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
