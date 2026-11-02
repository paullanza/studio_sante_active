class ConsultationsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_consultation, only: [:edit, :update, :destroy, :row, :association, :associate, :service_select, :disassociate]
  before_action :load_staff,       only: [:new, :create, :edit, :update]

  OWNER_REQUIRED_MESSAGE = "Veuillez choisir un·e employé·e.".freeze

  def new
    authorize Consultation

    @consultation = Consultation.new
    @consultations = Consultation
      .unconfirmed
      .where(user_id: current_user.id)
      .with_associations
      .order_by_occurred_at_desc
      .limit(25)
  end

  def create
    authorize Consultation

    @consultation = Consultation.new(permitted_attributes(Consultation))

    @consultation.user           = chosen_owner_for_create
    @consultation.created_by_id  = current_user.id
    @consultation.confirmed      = false
    assign_occurred_at(@consultation, params[:consultation][:date], params[:consultation][:time])

    if @consultation.user.present? && @consultation.save
      redirect_to new_seance_path, notice: "Consultation créée."
    else
      @consultation.errors.add(:base, OWNER_REQUIRED_MESSAGE) if @consultation.user.nil?
      @consultations = Consultation
        .unconfirmed
        .where(user_id: current_user.id)
        .with_associations
        .order_by_occurred_at_desc
        .limit(25)
      render :new, status: :unprocessable_content
    end
  end

  def edit
    authorize @consultation

    render partial: "consultations/shared/consultation_edit_row",
           locals:  { consultation: @consultation, show_bulk_checkbox: params[:show_bulk].present? },
           layout:  false
  end

  def row
    authorize @consultation
    render partial: "consultations/shared/consultation_row",
           locals:  { consultation: @consultation, show_bulk_checkbox: params[:show_bulk].present? },
           layout:  false
  end

  def update
    authorize @consultation

    @consultation.first_name   = params.dig(:consultation, :first_name).to_s
    @consultation.last_name    = params.dig(:consultation, :last_name).to_s
    @consultation.email        = params.dig(:consultation, :email).to_s
    @consultation.phone_number = params.dig(:consultation, :phone_number).to_s

    @consultation.note         = params.dig(:consultation, :note).to_s
    @consultation.present      = params.dig(:consultation, :present) == "1"
    assign_occurred_at(@consultation, params.dig(:consultation, :date), params.dig(:consultation, :time))

    uid = permitted_attributes(@consultation)[:user_id]
    if uid.present? && uid.to_i != @consultation.user_id
      @consultation.user       = User.selectable.find_by(id: uid)
      @consultation.created_by = current_user
    end

    if @consultation.user.present? && @consultation.save
      render partial: "consultations/shared/consultation_row",
             locals:  { consultation: @consultation, show_bulk_checkbox: params[:show_bulk].present? },
             layout:  false
    else
      @consultation.errors.add(:base, OWNER_REQUIRED_MESSAGE) if @consultation.user.nil?
      render partial: "consultations/shared/consultation_edit_row",
             locals:  { consultation: @consultation, show_bulk_checkbox: params[:show_bulk].present? },
             status:  :unprocessable_content,
             layout:  false
    end
  end

  def association
    authorize @consultation

    load_fliip_users_for_association(@consultation)
    load_services_for(@selected_fliip_user_id, cutoff_date: consultation_cutoff_date(@consultation))
    @prefill_name = prefill_name_for(@selected_fliip_user_id, @consultation)

    render partial: "consultations/shared/consultation_associate_row",
           locals:  { consultation: @consultation, show_bulk_checkbox: params[:show_bulk].present? },
           layout:  false
  end

  def associate
    authorize @consultation

    selected_user_id    = params[:fliip_user_id].presence
    selected_service_id = params[:fliip_service_id].presence

    @consultation.fliip_user_id = selected_user_id

    service = nil
    if selected_service_id.present?
      service = find_available_service_for_association(
        service_id:    selected_service_id,
        fliip_user_id: selected_user_id,
        cutoff_date:   consultation_cutoff_date(@consultation)
      )
      if service.nil?
        @consultation.errors.add(:fliip_service_id, "n’est pas disponible pour association (client/date/association existante).")
      end
    end

    @consultation.fliip_service_id = service&.id if @consultation.errors.empty?

    if @consultation.errors.empty? && @consultation.save
      render partial: "consultations/shared/consultation_row",
             locals:  { consultation: @consultation, show_bulk_checkbox: params[:show_bulk].present? },
             layout:  false
    else
      load_fliip_users_for_association(@consultation)
      @selected_fliip_user_id = selected_user_id if selected_user_id.present?
      load_services_for(@selected_fliip_user_id, cutoff_date: consultation_cutoff_date(@consultation))
      @prefill_name = prefill_name_for(@selected_fliip_user_id, @consultation)

      render partial: "consultations/shared/consultation_associate_row",
             locals:  { consultation: @consultation, show_bulk_checkbox: params[:show_bulk].present? },
             status:  :unprocessable_content,
             layout:  false
    end
  end

  def disassociate
    authorize @consultation

    @consultation.update(fliip_service_id: nil, fliip_user_id: nil)

    if request.xhr?
      render partial: "consultations/shared/consultation_row",
             locals:  { consultation: @consultation, show_bulk_checkbox: params[:show_bulk].present? },
             layout:  false
    else
      respond_to do |format|
        format.html { redirect_to request.referer || new_consultation_path, notice: "Association retirée." }
        format.turbo_stream if respond_to?(:turbo_stream)
      end
    end
  end

  def service_select
    authorize @consultation

    fliip_user_id = params.require(:fliip_user_id)
    @selected_id  = params[:selected_id]

    load_services_for(fliip_user_id, cutoff_date: consultation_cutoff_date(@consultation))

    render partial: "consultations/service_select",
          locals:  { services: (@services || []), selected_id: @selected_id },
          layout:  false
  end

  def destroy
    authorize @consultation

    @consultation.destroy
    respond_to do |format|
      format.json { head :no_content }
      format.html { redirect_back fallback_location: new_consultation_path, notice: "Consultation supprimée." }
    end
  end

  def associations
    authorize Consultation

    @filter_params = {
      q:                      params[:q].presence,
      employee_id:            params[:employee_id].presence,
      consultation_date_from: params[:consultation_date_from].presence,
      consultation_date_to:   params[:consultation_date_to].presence,
      created_from:           params[:created_from].presence,
      created_to:             params[:created_to].presence,
      present:                Array(params[:present]).presence
    }

    @staff = User.selectable.order(:first_name, :last_name)

    base = Consultation.unassociated.with_associations
    @consultations = base.apply_filters(@filter_params).order_by_occurred_at_desc
    @consultations = @consultations.limit(100) unless @consultations.respond_to?(:page)
  end

  private

  def set_consultation
    @consultation = Consultation.find(params[:id])
  end

  # Matches SessionsController#load_staff
  def load_staff
    @staff = policy(Consultation).change_owner? ? User.selectable.order(:first_name, :last_name) : []
    # The super admin is not selectable, so must pick an employee.
    @owner_required = @staff.any? && @staff.none? { |u| u.id == current_user.id }
  end

  # Keeps this controller's existing response formats. service_select
  # always answered with a bare 403.
  def user_not_authorized
    return head :forbidden if action_name == "service_select"

    respond_to do |format|
      format.json { head :forbidden }
      format.html { redirect_back fallback_location: new_consultation_path, alert: "Non autorisé·e." }
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

  def consultation_cutoff_date(consultation)
    (consultation.occurred_at&.to_date) || Date.current
  end

  def load_fliip_users_for_association(consultation)
    service_user_ids = FliipService.distinct.pluck(:fliip_user_id)

    @fliip_users = FliipUser.where(id: service_user_ids).sort_by do |u|
      I18n.transliterate("#{u.user_lastname.to_s.strip} #{u.user_firstname.to_s.strip}").downcase
    end

    query = [consultation.first_name, consultation.last_name].compact_blank.join(" ")
    @selected_fliip_user_id = nil

    if query.present?
      best = FliipUser.search_clients(query).limit(1).pluck(:id).first
      @selected_fliip_user_id = best if best.present?
    end
  end

  def load_services_for(fliip_user_id, cutoff_date:)
    return @services = [] if fliip_user_id.blank?
    cutoff = cutoff_date || Date.current

    @services = FliipService.available_for_association(
      fliip_user_id: fliip_user_id,
      cutoff_date:   cutoff
    )
  end

  def find_available_service_for_association(service_id:, fliip_user_id:, cutoff_date:)
    FliipService.find_available_for_association(
      service_id:    service_id,
      fliip_user_id: fliip_user_id,
      cutoff_date:   cutoff_date
    )
  end

  def prefill_name_for(selected_fliip_user_id, consultation)
    if selected_fliip_user_id.present?
      if (u = FliipUser.select(:id, :user_firstname, :user_lastname).find_by(id: selected_fliip_user_id))
        return u.full_name
      end
    end
    "Aucun client ne correspond à cette consultation."
  end
end
