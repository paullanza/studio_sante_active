class SessionsController < ApplicationController
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
    @session.present     = params[:session][:present] == "1"
    @session.duration    = params[:half_hour] == "1" ? 0.5 : 1.0

    if @session.user.present? && @session.save
      redirect_to new_seance_path, notice: "Séance créée avec succès."
    else
      @session.errors.add(:base, OWNER_REQUIRED_MESSAGE) if @session.user.nil?

      # Rehydrate everything the :new template needs
      load_fliip_users
      load_staff
      @sessions = Session
                    .where(user_id: current_user.id)
                    .unconfirmed
                    .with_associations
                    .order_by_occurred_at_desc
                    .limit(25)

      # If a client was selected, preload services so frames can render server-side
      if @session.fliip_user_id.present?
        @services = FliipService
                      .where(fliip_user_id: @session.fliip_user_id)
                      .includes(:fliip_user, :service_definition, :service_usage_adjustments)
                      .order(:expire_date, :service_name)
      else
        @services = []
      end

      @consultation = Consultation.new

      # Let the page render inline errors (422 is fine)
      flash.now[:alert] = @session.errors.full_messages.to_sentence.presence ||
                          "Un problème est survenu lors de la création de la séance."
      render "bookings/new", status: :unprocessable_content
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

  def preview_type
    authorize Session

    fliip_service_id = params[:fliip_service_id]
    present          = params[:present] == "1"
    duration         = (params[:half_hour] == "1") ? 0.5 : 1.0

    svc = FliipService
            .includes(:service_definition, :service_usage_adjustments, :sessions)
            .find_by(id: fliip_service_id)

    return render json: { error: "Service introuvable" }, status: :not_found unless svc

    s = Session.new(fliip_service: svc, present: present, duration: duration)
    # Important: reuse your model’s classification logic
    s.send(:set_session_type_and_duration)

    render json: { session_type: s.session_type } # "free" or "paid"
  end

  def services_table
    authorize Session

    fliip_user_id = params.require(:fliip_user_id)
    @services = FliipService
                  .where(fliip_user_id: fliip_user_id)
                  .includes(:fliip_user, :service_definition, :service_usage_adjustments)
                  .order(expire_date: :desc, service_name: :asc)

    render :services_table, layout: false
  end

  # Turbo Frame: the <select name="session[fliip_service_id]">, server-rendered
  def service_select
    authorize Session

    fliip_user_id   = params.require(:fliip_user_id)
    @selected_id    = params[:selected_id] # optional
    @services = FliipService
                  .where(fliip_user_id: fliip_user_id)
                  .includes(:fliip_user, :service_definition, :service_usage_adjustments)
                  .order(expire_date: :desc, service_name: :asc)

    render :service_select, layout: false
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

  def load_fliip_users
    service_user_ids = FliipService.distinct.pluck(:fliip_user_id)

    @fliip_users = FliipUser
      .where(id: service_user_ids)
      .sort_by do |u|
        I18n.transliterate("#{u.user_lastname.to_s.strip} #{u.user_firstname.to_s.strip}").downcase
      end
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
