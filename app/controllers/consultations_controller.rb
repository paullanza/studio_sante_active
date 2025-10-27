class ConsultationsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_consultation, only: [:edit, :update, :destroy, :row]
  before_action :load_staff,       only: [:new, :create, :edit, :update]

  def new
    @consultation = Consultation.new
    @consultations = Consultation
      .where(confirmed: [false, nil])
      .where(user_id: current_user.id)
      .order(occurred_at: :desc, created_at: :desc)
      .includes(:user)
      .limit(25)
  end

  def create
    @consultation = Consultation.new(consultation_params)

    # Defaults/attribution
    @consultation.user_id ||= current_user.id
    @consultation.created_by_id = current_user.id
    @consultation.confirmed = false
    assign_occurred_at(@consultation, params[:consultation][:date], params[:consultation][:time])

    if @consultation.save
      redirect_to new_seance_path, notice: "Consultation créée."
    else
      @consultations = Consultation
        .where(confirmed: [false, nil])
        .where(user_id: current_user.id)
        .order(occurred_at: :desc, created_at: :desc)
        .includes(:user)
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

    # Assign fields explicitly (match your edit row inputs)
    @consultation.note    = params.dig(:consultation, :note).to_s
    @consultation.present = params.dig(:consultation, :present) == "1"
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

  private

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
end
