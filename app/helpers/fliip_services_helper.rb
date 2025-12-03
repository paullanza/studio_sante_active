module FliipServicesHelper
  def purchase_status_badge_class(status)
    case status
    when "A" then "bg-success"
    when "P" then "bg-info text-dark"
    when "S" then "bg-warning text-dark"
    when "C" then "bg-danger"
    else           "bg-secondary"
    end
  end

  def svc_time_range_label(svc)
    sd = svc.start_date&.strftime("%d/%m/%Y")
    ed = svc.expire_date&.strftime("%d/%m/%Y")
    return "#{sd}–#{ed}" if sd && ed
    return "#{sd}–?"     if sd
    return "?–#{ed}"     if ed
    "—"
  end

  def svc_time_progress_percent(svc)
    start  = svc.start_date || svc.purchase_date&.to_date
    finish = svc.expire_date
    return 0 unless start && finish && finish > start
    (((Date.current - start).to_f / (finish - start).to_f) * 100).clamp(0, 100).round
  end

  # returns a pair of classes for bg + text readability
  def progress_color_classes(percent)
    p = percent.to_i
    return ["bg-secondary", "text-white"] if p <= 0
    case p
    when 0..49   then ["bg-success",  "text-white"]
    when 50..74  then ["bg-warning",  "text-dark"]
    when 75..94  then ["bg-orange",   "text-dark"]  # custom orange
    else              ["bg-danger",   "text-white"]
    end
  end

  def fmt1(n)
    ("%.1f" % n.to_f)
  end

  # A service is considered "complete" for the paid bar when:
  # - it has a positive allowed total AND all paid sessions are used, OR
  # - the paid progress percent is at least 100% (safety net for rounding).
  def paid_progress_complete?(svc, percent)
    svc.paid_allowed_total.to_f.positive? &&
      (svc.fully_used? || percent.to_i >= 100)
  end

  # Builds the label for the paid usage progress bar.
  # - If complete → "Complet - used/total 100%"
  # - Otherwise   → compact usage + absences + percentage (legacy format)
  def paid_progress_label(svc, percent)
    pct = percent.to_i

    if paid_progress_complete?(svc, percent)
      used  = fmt1(svc.paid_used_total)
      total = fmt1(svc.paid_allowed_total)
      "Complet - #{used}/#{total} #{pct}%"
    else
      "#{svc.paid_usage_compact_str} #{svc.absences_compact_str} • #{pct}%"
    end
  end

  # Selects the background class for the paid usage progress bar.
  # - If complete → green
  # - Otherwise   → keep discrepancy-based color logic
  def paid_progress_bg_class(svc, paid_pct, time_pct)
    return "bg-success" if paid_progress_complete?(svc, paid_pct)

    progress_usage_color(paid_pct, time_pct)
  end
end
