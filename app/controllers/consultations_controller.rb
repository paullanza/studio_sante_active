class ConsultationsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_consultation, only: [:edit, :update, :destroy, :row, :association, :associate, :service_select, :disassociate]
  before_action :load_staff,       only: [:new, :create, :edit, :update]
  before_action :ensure_management!, only: [:associations]

  def new
    @consultation = Consultation.new
    @consultations = Consultation
      .unconfirmed
      .where(user_id: current_user.id)
      .with_associations
      .order_by_occurred_at_desc
      .limit(25)
  end

  def create
    @consultation = Consultation.new(consultation_params)

    @consultation.user_id       ||= current_user.id
    @consultation.created_by_id  = current_user.id
    @consultation.confirmed      = false
    assign_occurred_at(@consultation, params[:consultation][:date], params[:consultation][:time])

    if @consultation.save
      redirect_to new_seance_path, notice: "Consultation créée."
    else
      @consultations = Consultation
        .unconfirmed
        .where(user_id: current_user.id)
        .with_associations
        .order_by_occurred_at_desc
        .limit(25)
      render :new, status: :unprocessable_entity
    end
  end

  def can_modify?(consultation, action:)
    consultation.modifiable_by?(current_user)
  end

  def edit
    return forbid unless can_modify?(@consultation, action: :edit)

    render partial: "consultations/shared/consultation_edit_row",
           locals:  { consultation: @consultation, show_bulk_checkbox: params[:show_bulk].present? },
           layout:  false
  end

  def row
    render partial: "consultations/shared/consultation_row",
           locals:  { consultation: @consultation, show_bulk_checkbox: params[:show_bulk].present? },
           layout:  false
  end

  def update
    return forbid unless can_modify?(@consultation, action: :update)

    @consultation.first_name   = params.dig(:consultation, :first_name).to_s
    @consultation.last_name    = params.dig(:consultation, :last_name).to_s
    @consultation.email        = params.dig(:consultation, :email).to_s
    @consultation.phone_number = params.dig(:consultation, :phone_number).to_s

    @consultation.note         = params.dig(:consultation, :note).to_s
    @consultation.present      = params.dig(:consultation, :present) == "1"
    assign_occurred_at(@consultation, params.dig(:consultation, :date), params.dig(:consultation, :time))

    if admin_like? && (uid = params.dig(:consultation, :user_id)).present?
      @consultation.user_id    = uid
      @consultation.created_by = current_user
    end

    if @consultation.save
      render partial: "consultations/shared/consultation_row",
             locals:  { consultation: @consultation, show_bulk_checkbox: params[:show_bulk].present? },
             layout:  false
    else
      render partial: "consultations/shared/consultation_edit_row",
             locals:  { consultation: @consultation, show_bulk_checkbox: params[:show_bulk].present? },
             status:  :unprocessable_entity,
             layout:  false
    end
  end

  def association
    return forbid unless can_modify?(@consultation, action: :edit)

    load_fliip_users_for_association(@consultation)
    load_services_for(@selected_fliip_user_id, cutoff_date: consultation_cutoff_date(@consultation))
    @prefill_name = prefill_name_for(@selected_fliip_user_id, @consultation)

    render partial: "consultations/shared/consultation_associate_row",
           locals:  { consultation: @consultation, show_bulk_checkbox: params[:show_bulk].present? },
           layout:  false
  end

  def associate
    return forbid unless can_modify?(@consultation, action: :update)

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
             status:  :unprocessable_entity,
             layout:  false
    end
  end

  def disassociate
    @consultation = Consultation.find(params[:id])

    if current_user&.admin? || @consultation.user_id == current_user&.id
      @consultation.update(fliip_service_id: nil, fliip_user_id: nil)

      if request.xhr?
        render partial: "consultations/shared/consultation_row",
               locals:  { consultation: @consultation, show_bulk_checkbox: params[:show_bulk].present? },
               layout:  false
      else
        respond_to do |format|
          format.html { redirect_to request.referer || consultations_path, notice: "Association retirée." }
          format.turbo_stream if respond_to?(:turbo_stream)
        end
      end
    else
      redirect_to request.referer || consultations_path, alert: "Non autorisé·e."
    end
  end

  def service_select
    return head :forbidden unless can_modify?(@consultation, action: :edit)

    fliip_user_id = params.require(:fliip_user_id)
    @selected_id  = params[:selected_id]

    load_services_for(fliip_user_id, cutoff_date: consultation_cutoff_date(@consultation))

    render partial: "consultations/service_select",
          locals:  { services: (@services || []), selected_id: @selected_id },
          layout:  false
  end

  def destroy
    unless can_modify?(@consultation, action: :destroy)
      return respond_to do |format|
        format.json { head :forbidden }
        format.html { redirect_back fallback_location: new_consultation_path, alert: "Non autorisé·e." }
      end
    end

    @consultation.destroy
    respond_to do |format|
      format.json { head :no_content }
      format.html { redirect_back fallback_location: new_consultation_path, notice: "Consultation supprimée." }
    end
  end

  def associations
    @filter_params = {
      q:                      params[:q].presence,
      employee_id:            params[:employee_id].presence,
      consultation_date_from: params[:consultation_date_from].presence,
      consultation_date_to:   params[:consultation_date_to].presence,
      created_from:           params[:created_from].presence,
      created_to:             params[:created_to].presence,
      present:                Array(params[:present]).presence
    }

    @staff = User.where(active: true).order(:first_name, :last_name) if management_user?

    base = Consultation.unassociated.with_associations
    @consultations = base.apply_filters(@filter_params).order_by_occurred_at_desc
    @consultations = @consultations.limit(100) unless @consultations.respond_to?(:page)
  end

  private

  def ensure_management!
    return if management_user?
    forbid
  end

  def management_user?
    admin_like? || (current_user.respond_to?(:manager?) && current_user.manager?)
  end

  def set_consultation
    @consultation = Consultation.find(params[:id])
  end

  def admin_like?
    current_user.admin? || (current_user.respond_to?(:super_admin?) && current_user.super_admin?)
  end

  def load_staff
    @staff = if admin_like?
      User.where(active: true).order(:first_name, :last_name)
    else
      []
    end
  end

  def forbid
    respond_to do |format|
      format.json { head :forbidden }
      format.html { redirect_back fallback_location: new_consultation_path, alert: "Non autorisé·e." }
    end
  end

  def consultation_params
    params.require(:consultation).permit(
      :first_name,
      :last_name,
      :email,
      :phone_number,
      :note,
      :present,
      :user_id
    )
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
