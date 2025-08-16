# app/controllers/sessions_controller.rb
class SessionsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_session, only: [:update, :destroy]

  def new
    @session = Session.new
    load_fliip_users
  end

  def create
    @session = Session.new(session_params)

    @session.user      = chosen_creator_for_create # <- new
    @session.confirmed = false
    @session.present   = params[:session][:present] == "1"
    @session.duration  = params[:half_hour] == "1" ? 0.5 : 1.0

    if @session.save
      redirect_to new_session_path, notice: "Session created successfully."
    else
      load_fliip_users
      flash.now[:alert] = @session.errors.full_messages.to_sentence.presence || "There was a problem creating the session."
      render :new, status: :unprocessable_entity
    end
  end

  def update
    @session.assign_attributes(session_params)

    # present flag (same semantics as create)
    present_param = params[:session][:present]
    unless present_param.nil?
      @session.present = (present_param == "1")
      @session.session_type = "paid" if @session.present?
    end

    # half_hour flag (same semantics as create)
    half_hour = params[:session][:half_hour]
    unless half_hour.nil?
      @session.duration = (half_hour == "1") ? 0.5 : 1.0
    end

    # NEW: allow admin to reassign creator
    creator_id = chosen_creator_id_from_params
    @session.user_id = creator_id if creator_id

    if @session.save
      respond_to do |format|
        format.json { render json: session_payload(@session), status: :ok }
        format.html { redirect_back fallback_location: admin_unconfirmed_sessions_path, notice: "Session updated." }
      end
    else
      respond_to do |format|
        format.json { render json: { errors: @session.errors.full_messages }, status: :unprocessable_entity }
        format.html  { redirect_back fallback_location: admin_unconfirmed_sessions_path, alert: @session.errors.full_messages.to_sentence }
      end
    end
  end

  def destroy
    unless current_user.admin? || current_user.super_admin?
      return respond_to do |format|
        format.json { head :forbidden }
        format.html  { redirect_back fallback_location: admin_unconfirmed_sessions_path, alert: "Not authorized." }
      end
    end

    @session.destroy
    respond_to do |format|
      format.json { head :no_content }
      format.html { redirect_back fallback_location: admin_unconfirmed_sessions_path, notice: "Session deleted." }
    end
  end

  # GET /sessions/services_for_user?fliip_user_id=...
  def services_for_user
    fliip_user_id = params.require(:fliip_user_id)

    services = FliipService
      .where(fliip_user_id: fliip_user_id)
      .includes(:service_definition, :service_usage_adjustments) # avoid N+1 for helpers
      .order(:expire_date, :service_name)

    today        = Date.current
    future_limit = today + 1.month
    past_limit   = today - 1.month

    status_label = {
      "A" => "Active", "I" => "Inactive", "P" => "Planned",
      "C" => "Cancelled", "S" => "Stopped"
    }.freeze

    payload = services.map do |svc|
      starts_too_late = svc.start_date.present?  && svc.start_date  > future_limit
      ended_too_long  = svc.expire_date.present? && svc.expire_date < past_limit
      selectable      = !(starts_too_late || ended_too_long)

      # Dates label + time progress (fallback to 0 when missing)
      time_label =
        if svc.start_date.present? && svc.expire_date.present?
          "#{svc.start_date.strftime('%d/%m/%Y')} → #{svc.expire_date.strftime('%d/%m/%Y')}"
        else
          "—"
        end

      time_pct =
        if svc.start_date.present? && svc.expire_date.present? && svc.start_date <= svc.expire_date
          range_days = (svc.expire_date - svc.start_date).to_f
          pos_days   = (today - svc.start_date).to_f
          pct = range_days <= 0 ? 0 : (pos_days / range_days * 100.0)
          [[pct, 0].max, 100].min.round
        else
          0
        end

      # Use model helpers so adjustments are included and everything stays consistent with the views
      paid_used_total   = svc.paid_used_total
      paid_included     = svc.service_definition&.paid_sessions
      paid_bonus_total  = svc.paid_bonus_total
      paid_allowed_total= svc.paid_allowed_total
      paid_pct          = svc.paid_progress_percent || 0

      free_used_total   = svc.free_used_total
      free_included     = svc.service_definition&.free_sessions

      {
        id:                    svc.id,
        fliip_user_id:         svc.fliip_user_id,
        remote_purchase_id:    svc.remote_purchase_id,
        service_name:          svc.service_name,
        status:                svc.purchase_status,
        status_label:          status_label[svc.purchase_status] || "-",
        start_date:            svc.start_date,
        expire_date:           svc.expire_date,
        purchase_date:         svc.purchase_date,
        stop_date:             svc.stop_date,
        cancel_date:           svc.cancel_date,
        duration:              svc.duration,
        selectable:            selectable,

        # ---- flat fields (backward/forward compatible with your Stimulus) ----
        paid_used_total:       paid_used_total,
        paid_included:         paid_included,
        paid_bonus_total:      paid_bonus_total,
        paid_allowed_total:    paid_allowed_total,
        paid_usage_percent:    paid_pct,

        free_used_total:       free_used_total,
        free_included:         free_included,

        # Keep older names too, in case anything still reads them
        paid_used:             paid_used_total,
        paid_total:            paid_included,
        free_used:             free_used_total,
        free_total:            free_included,

        # time UI
        time_range_label:      time_label,
        time_progress_percent: time_pct,

        # ---- nested usage_stats (matches FliipService#usage_stats) ----
        usage_stats: {
          paid: {
            used_sessions:  paid_used_total,
            included:       paid_included,
            bonus:          paid_bonus_total,
            allowed_total:  paid_allowed_total,
            remaining:      svc.remaining_paid_sessions
          },
          free: {
            used_sessions:  free_used_total,
            included:       free_included,
            allowed_total:  svc.free_allowed_total,
            remaining:      svc.remaining_free_sessions
          }
        }
      }
    end

    render json: payload
  end

  def refresh_clients
    msg = FliipApi::UserSync::NewUserImporter.call
    redirect_to new_session_path, notice: msg
  rescue => e
    redirect_to new_session_path, alert: "Could not refresh clients: #{e.message}"
  end

  private

  def chosen_creator_for_create
    if (id = chosen_creator_id_from_params)
      User.find(id)
    else
      current_user
    end
  end

  def chosen_creator_id_from_params
    return nil unless (current_user.admin? || current_user.super_admin?)
    id = params.dig(:session, :user_id)
    id.presence
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
