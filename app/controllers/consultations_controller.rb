class ConsultationsController < ApplicationController
  include BookingPage

  before_action :authenticate_user!
  before_action :set_consultation, only: [:edit, :update, :destroy, :row, :association, :associate, :disassociate]
  layout "studio", only: [:associations]
  before_action :load_staff,       only: [:create, :edit, :update]

  OWNER_REQUIRED_MESSAGE = "Veuillez choisir un·e employé·e.".freeze

  def create
    authorize Consultation

    @consultation = Consultation.new(permitted_attributes(Consultation))

    @consultation.user           = chosen_owner_for_create
    @consultation.created_by_id  = current_user.id
    @consultation.confirmed      = false
    assign_occurred_at(@consultation, params[:consultation][:date], params[:consultation][:time])

    if @consultation.user.present? && @consultation.save
      redirect_to new_seance_path(tab: "consultation"), notice: "Consultation enregistrée."
    else
      @consultation.errors.add(:base, OWNER_REQUIRED_MESSAGE) if @consultation.user.nil?

      prepare_booking_page(client_id: nil, tab: "consultation")
      render "bookings/new", layout: "studio", status: :unprocessable_content
    end
  end

  def edit
    authorize @consultation
    return render_edit_card if turbo_frame_request?

    render partial: "consultations/shared/consultation_edit_row",
           locals:  { consultation: @consultation, show_bulk_checkbox: params[:show_bulk].present? },
           layout:  false
  end

  # The consultation's card (« Annuler » in the edit card), or the old table row.
  def row
    authorize @consultation
    return render partial: "consultations/card", locals: { consultation: @consultation, context: params[:context] } if turbo_frame_request?

    render partial: "consultations/shared/consultation_row",
           locals:  { consultation: @consultation, show_bulk_checkbox: params[:show_bulk].present? },
           layout:  false
  end

  # The new pages (Saisir, Client, Service) answer with Turbo Streams; the old
  # admin tables still get their row partials.
  def update
    authorize @consultation

    attributes = permitted_attributes(@consultation)
    @consultation.assign_attributes(attributes.except(:user_id))
    assign_occurred_at(@consultation, params.dig(:consultation, :date), params.dig(:consultation, :time))

    uid = attributes[:user_id]
    if uid.present? && uid.to_i != @consultation.user_id
      @consultation.user       = User.selectable.find_by(id: uid)
      @consultation.created_by = current_user
    end

    saved = @consultation.user.present? && @consultation.save
    @consultation.errors.add(:base, OWNER_REQUIRED_MESSAGE) if @consultation.user.nil?

    if request.format.turbo_stream?
      return render_edit_card(status: :unprocessable_content) unless saved

      render turbo_stream: turbo_stream.replace(helpers.dom_id(@consultation), partial: "consultations/card",
                                                                               locals: { consultation: @consultation, context: params[:context] })
    elsif saved
      render partial: "consultations/shared/consultation_row",
             locals:  { consultation: @consultation, show_bulk_checkbox: params[:show_bulk].present? },
             layout:  false
    else
      render partial: "consultations/shared/consultation_edit_row",
             locals:  { consultation: @consultation, show_bulk_checkbox: params[:show_bulk].present? },
             status:  :unprocessable_content,
             layout:  false
    end
  end

  # The link form, in the consultation card's frame: the chosen client (or the
  # best name match), then their services in the link window.
  def association
    authorize @consultation
    render_link_form(client: chosen_client)
  end

  # Links the consultation to a client and, optionally, one of their services.
  # On « Lier les consultations » a card with a service leaves the list.
  def associate
    authorize @consultation

    client = FliipUser.find_by(id: params[:fliip_user_id])
    @consultation.fliip_user = client
    @consultation.fliip_service = FliipService.find_by(id: params[:fliip_service_id]) if client && params[:fliip_service_id].present?
    @consultation.errors.add(:fliip_user_id, "doit être choisi") if client.nil?

    if client && @consultation.save
      respond_to do |format|
        format.turbo_stream { render turbo_stream: linked_card_stream }
        format.html { redirect_to associations_consultations_path, notice: "Consultation liée." }
      end
    else
      render_link_form(client: client, status: :unprocessable_content)
    end
  end

  # Clears the client and the service (admins).
  def disassociate
    authorize @consultation

    @consultation.update(fliip_service_id: nil, fliip_user_id: nil)

    if request.xhr?
      render partial: "consultations/shared/consultation_row",
             locals:  { consultation: @consultation, show_bulk_checkbox: params[:show_bulk].present? },
             layout:  false
    else
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(helpers.dom_id(@consultation), partial: "consultations/card",
                                                                                   locals: { consultation: @consultation, context: params[:context] })
        end
        format.html { redirect_back fallback_location: associations_consultations_path, notice: "Liaison retirée." }
      end
    end
  end

  def destroy
    authorize @consultation

    @consultation.destroy
    respond_to do |format|
      format.turbo_stream { render turbo_stream: removed_card_streams }
      format.json { head :no_content }
      format.html { redirect_back fallback_location: new_seance_path(tab: "consultation"), notice: "Consultation supprimée." }
    end
  end

  # « Lier les consultations »: the consultations still without a service.
  def associations
    authorize Consultation

    @filter_params = {
      q:                      params[:q].presence,
      employee_id:            params[:employee_id].presence,
      consultation_date_from: params[:consultation_date_from].presence,
      consultation_date_to:   params[:consultation_date_to].presence
    }
    # A deactivated trainer stays in the list while their filter is on.
    @staff = User.selectable.or(User.where(id: @filter_params[:employee_id])).order(:first_name, :last_name)

    @pagy, @consultations = pagy(
      Consultation.to_link.apply_filters(@filter_params).with_associations.order_by_occurred_at_desc,
      limit: 25
    )
    @to_link_count = Consultation.to_link.count
  end

  private

  def set_consultation
    @consultation = Consultation.find(params[:id])
  end

  # The client the link form opens on: the one asked for, the one already
  # linked, else the best match for the prospect's name. Nil when none matches.
  def chosen_client
    return if params[:change].present?
    return FliipUser.find_by(id: params[:fliip_user_id]) if params[:fliip_user_id].present?
    return @consultation.fliip_user if @consultation.fliip_user

    FliipUser.search(@consultation.full_name).first
  end

  def render_link_form(client:, status: :ok)
    services = client ? FliipService.available_for_association(fliip_user_id: client.id, base_date: @consultation.occurred_at).to_a : []
    counts = Consultation.where(fliip_service_id: services.map(&:id)).where.not(id: @consultation.id)
                         .group(:fliip_service_id).count
    locals = { consultation: @consultation, client: client, services: services, counts: counts, context: params[:context] }

    if request.format.turbo_stream?
      render turbo_stream: turbo_stream.replace(helpers.dom_id(@consultation), partial: "consultations/link_form", locals: locals), status: status
    else
      render partial: "consultations/link_form", locals: locals, status: status
    end
  end

  # After a link: on « Lier les consultations » the card leaves once it has a
  # service; elsewhere it is drawn again.
  def linked_card_stream
    if params[:context] == "lier" && @consultation.fliip_service_id
      return [
        turbo_stream.remove(helpers.dom_id(@consultation, :item)),
        turbo_stream.update("to_link_count", Consultation.to_link.count.to_s)
      ]
    end

    turbo_stream.replace(helpers.dom_id(@consultation), partial: "consultations/card",
                                                         locals: { consultation: @consultation, context: params[:context] })
  end

  # After a delete: the card goes, and the Client or Service page's tab count
  # follows. On Confirmations the trainer's count drops, and the group goes
  # with its last consultation.
  def removed_card_streams
    return removed_confirmation_streams if params[:context] == "confirmations"

    streams = [ turbo_stream.remove(helpers.dom_id(@consultation, :item)) ]
    owner, column = case params[:context]
    when "client" then [ @consultation.fliip_user, :fliip_user_id ]
    when "service" then [ @consultation.fliip_service, :fliip_service_id ]
    end
    return streams unless owner

    streams << turbo_stream.update(helpers.dom_id(owner, :consultations_count), Consultation.where(column => owner.id).count.to_s)
  end

  def removed_confirmation_streams
    period = PayPeriod.containing(@consultation.occurred_at.to_date)
    left = Consultation.unconfirmed.in_period(period).where(user_id: @consultation.user_id).count
    return turbo_stream.remove(helpers.dom_id(@consultation.user, :confirm_section)) if left.zero?

    [
      turbo_stream.remove(helpers.dom_id(@consultation, :item)),
      turbo_stream.update(helpers.dom_id(@consultation.user, :confirm_count), "#{left} consultation(s)")
    ]
  end

  # The edit card, in the consultation's frame (or as a stream after a failed save).
  def render_edit_card(status: :ok)
    locals = { consultation: @consultation, context: params[:context] }
    if request.format.turbo_stream?
      render turbo_stream: turbo_stream.replace(helpers.dom_id(@consultation), partial: "consultations/edit_card", locals: locals), status: status
    else
      render partial: "consultations/edit_card", locals: locals, status: status
    end
  end

  # Matches SessionsController#load_staff
  def load_staff
    @staff = policy(Consultation).change_owner? ? User.selectable.order(:first_name, :last_name) : []
    # The super admin is not selectable, so must pick an employee.
    @owner_required = @staff.any? && @staff.none? { |u| u.id == current_user.id }
  end

  # Keeps this controller's existing response formats.
  def user_not_authorized
    respond_to do |format|
      format.turbo_stream { head :forbidden }
      format.json { head :forbidden }
      format.html { redirect_back fallback_location: new_seance_path(tab: "consultation"), alert: "Non autorisé·e." }
    end
  end

  # Nil when the owner is not selectable, such as a super admin who left
  # the employee blank.
  def chosen_owner_for_create
    return current_user unless policy(Consultation).change_owner?

    id = params.dig(:consultation, :user_id).presence || current_user.id
    User.selectable.find_by(id: id)
  end

  def assign_occurred_at(record, date_str, time_str)
    return if date_str.blank? && time_str.blank?

    date_part = date_str.presence || Time.zone.today.to_s
    time_part = time_str.presence || "09:00"
    begin
      record.occurred_at = Time.zone.parse("#{date_part} #{time_part}")
    rescue ArgumentError
      record.occurred_at ||= Time.zone.now
    end
  end
end
