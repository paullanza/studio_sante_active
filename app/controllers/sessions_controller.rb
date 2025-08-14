# app/controllers/sessions_controller.rb
class SessionsController < ApplicationController
  before_action :authenticate_user!

  def new
    @session = Session.new
    load_fliip_users
  end

  def create
    @session = Session.new(session_params)
    @session.user      = current_user
    @session.confirmed = false
    @session.present   = params[:session][:present] == "1"
    @session.duration  = params[:half_hour] == "1" ? 0.5 : 1.0

    if @session.save
      # Stay on the new page with a cleared form
      redirect_to new_session_path, notice: "Session created successfully."
    else
      load_fliip_users
      flash.now[:alert] = @session.errors.full_messages.to_sentence.presence || "There was a problem creating the session."
      render :new, status: :unprocessable_entity
    end
  end

  # GET /sessions/services_for_user?fliip_user_id=...
  def services_for_user
    fliip_user_id = params.require(:fliip_user_id)

    services = FliipService
      .where(fliip_user_id: fliip_user_id)
      .includes(:service_definition)
      .order(:expire_date, :service_name)

    usage_sums = Session
      .where(fliip_service_id: services.ids)
      .group(:fliip_service_id, :session_type)
      .sum(:duration)

    today        = Date.current
    future_limit = today + 1.month
    past_limit   = today - 1.month

    status_label = { "A" => "Active", "I" => "Inactive", "P" => "Planned", "C" => "Cancelled", "S" => "Stopped" }

    payload = services.map do |svc|
      starts_too_late = svc.start_date.present?  && svc.start_date  > future_limit
      ended_too_long  = svc.expire_date.present? && svc.expire_date < past_limit
      selectable      = !(starts_too_late || ended_too_long)

      paid_used   = usage_sums.fetch([svc.id, "paid"], 0.0).to_f
      paid_total  = svc.service_definition&.paid_sessions
      paid_pct    = paid_total.to_f.positive? ? ((paid_used / paid_total.to_f) * 100).round : 0

      free_used   = usage_sums.fetch([svc.id, "free"], 0.0).to_f
      free_total  = svc.service_definition&.free_sessions

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

      {
        id:                     svc.id,
        fliip_user_id:          svc.fliip_user_id,
        remote_purchase_id:     svc.remote_purchase_id,
        service_name:           svc.service_name,
        status:                 svc.purchase_status,
        status_label:           status_label[svc.purchase_status] || "-",
        start_date:             svc.start_date,
        expire_date:            svc.expire_date,
        purchase_date:          svc.purchase_date,
        stop_date:              svc.stop_date,
        cancel_date:            svc.cancel_date,
        duration:               svc.duration,
        selectable:             selectable,
        paid_used:              paid_used,
        paid_total:             paid_total,
        paid_usage_percent:     paid_pct,
        free_used:              free_used,   # <-- NEW
        free_total:             free_total,  # <-- NEW
        time_range_label:       time_label,
        time_progress_percent:  time_pct
      }
    end

    render json: payload
  end

  def refresh_clients
    FliipApi::UserSync::NewUserImporter.call
    redirect_to new_session_path, notice: "Client list refreshed."
  rescue => e
    redirect_to new_session_path, alert: "Could not refresh clients: #{e.message}"
  end

  private

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
end
