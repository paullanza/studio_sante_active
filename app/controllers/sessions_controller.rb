class SessionsController < ApplicationController
  include BookingPage
  include StaffActivityStreams

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
      redirect_to new_seance_path, notice: "Séance enregistrée."
    else
      @session.errors.add(:base, OWNER_REQUIRED_MESSAGE) if @session.user.nil?

      prepare_booking_page(client_id: @session.fliip_user_id, tab: "session")
      render "bookings/new", layout: "studio", status: :unprocessable_content
    end
  end

  def edit
    authorize @session
    render_edit_card
  end

  # The séance's card (« Annuler » in the edit card).
  def row
    authorize @session
    render_frame_card
  end

  # Session#recalculate_type picks the outcome again when presence or duration
  # changed. The pages answer with Turbo Streams; a plain HTML request is sent
  # back where it came from.
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
      redirect_back fallback_location: new_seance_path, notice: "Séance modifiée."
    else
      redirect_back fallback_location: new_seance_path, alert: @session.errors.full_messages.to_sentence
    end
  end

  def destroy
    authorize @session

    @session.destroy
    respond_to do |format|
      format.turbo_stream { render turbo_stream: removed_row_streams || refreshed_lists }
      format.json { head :no_content }
      format.html { redirect_back fallback_location: session_confirmations_path, notice: "Séance supprimée." }
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

  # Pages whose séance stays one row after an edit: nothing else on them shows it.
  def listed_context?
    %w[confirmations recentes personnel].include?(params[:context])
  end

  # One hour unless the form sends another duration.
  def submitted_duration
    duration = params.dig(:session, :duration)
    duration.present? ? duration.to_f : 1.0
  end

  def render_edit_card(status: :ok)
    locals = { session: @session, context: params[:context], trainer_id: params[:trainer_id] }
    if request.format.turbo_stream?
      render turbo_stream: turbo_stream.replace(helpers.dom_id(@session), partial: "sessions/edit_card", locals: locals), status: status
    else
      render partial: "sessions/edit_card", locals: locals, status: status
    end
  end

  # The séance's card in its frame (sessions/_seance), as its page shows it:
  # Saisir's latest séances, Confirmations, Séances récentes, or the Service
  # page with its number.
  def render_frame_card
    render partial: "sessions/seance", locals: frame_card_locals
  end

  def frame_card_locals
    context = params[:context].presence
    locals = { session: @session, context: context, trainer_id: params[:trainer_id] }
    locals[:number] = Session.numbers_for([ @session ])[@session.id] unless saisir_context? || personnel_context?
    locals
  end

  # After an edit or a delete: the lists, counts and bars that show the séance.
  # A changed date can reorder the Service page's séances and their numbers, so
  # the whole list is drawn again.
  def refreshed_lists
    if listed_context?
      card = turbo_stream.replace(helpers.dom_id(@session), partial: "sessions/seance", locals: frame_card_locals)
      return personnel_context? ? [ card, *activity_totals_stream(listed_trainer, listed_at) ] : card
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

  # A séance deleted from a list that shows it alone (Confirmations, Séances
  # récentes): its row goes. On Confirmations its trainer's count drops too,
  # and the group goes with its last séance. Nil elsewhere.
  def removed_row_streams
    return turbo_stream.remove(helpers.dom_id(@session, :item)) if params[:context] == "recentes"
    if personnel_context?
      return [ turbo_stream.remove(helpers.dom_id(@session, :item)), *activity_totals_stream(@session.user, @session.occurred_at) ]
    end
    return unless confirmations_context?

    left = Session.unconfirmed.in_period(PayPeriod.containing(@session.occurred_at.to_date)).where(user_id: @session.user_id).count
    return turbo_stream.remove(helpers.dom_id(@session.user, :confirm_section)) if left.zero?

    [
      turbo_stream.remove(helpers.dom_id(@session, :item)),
      turbo_stream.update(helpers.dom_id(@session.user, :confirm_count), "#{left} séance(s)")
    ]
  end

  # The staff page the séance was listed on (only one the viewer may see), and
  # when it was, before this edit moved it.
  def listed_trainer
    page_user = User.find_by(id: params[:trainer_id])
    page_user && policy(page_user).show? ? page_user : @session.user
  end

  def listed_at
    @session.occurred_at_before_last_save || @session.occurred_at
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
