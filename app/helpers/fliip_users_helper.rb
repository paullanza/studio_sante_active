# app/helpers/fliip_users_helper.rb
module FliipUsersHelper
  # Returns 0..100 based on dates; 0 if missing/invalid
  def time_progress_percent(service, today: Date.current)
    sd = service.start_date
    ed = service.expire_date
    return 0 if sd.blank? || ed.blank? || ed <= sd

    span = (ed - sd).to_f
    elapsed = (today - sd).to_f
    pct = ((elapsed / span) * 100.0).round
    pct.clamp(0, 100)
  end

  # Returns 0..100 for paid usage; 0 if total is nil/0
  def paid_usage_percent(service, usage_sums)
    total = service.service_definition&.paid_sessions.to_i
    return 0 if total <= 0

    used = usage_sums.fetch([service.id, "paid"], 0.0).to_f
    pct = ((used / total) * 100.0).round
    pct.clamp(0, 100)
  end

  # Convenience labels (e.g., "7.5 / 24")
  def paid_usage_label(service, usage_sums)
    total = service.service_definition&.paid_sessions
    used  = usage_sums.fetch([service.id, "paid"], 0.0).to_f
    total ? "#{used}/#{total}" : "#{used}/—"
  end

  # Convenience for time label (e.g., "12 Aug 2025 → 12 Sep 2025")
  def time_range_label(service)
    sd = service.start_date&.strftime("%d/%m/%Y") || "—"
    ed = service.expire_date&.strftime("%d/%m/%Y") || "—"
    "#{sd} → #{ed}"
  end
end
