module FliipServicesHelper
  # One thin service bar (docs/ui.md « Progress bars »), the label above it.
  # Without `aside` the label row reads « Temps … 42 % »; with it, « Temps · 42 % »
  # on the left and the aside (« 120 jours restants ») on the right.
  def service_bar(label, percent, color_class, aside: nil)
    pct = percent.to_i
    pct_tag = tag.span("#{pct} %", class: "service-bar__pct")
    label_row = if aside
      safe_join([ tag.span(safe_join([ label, " · ", pct_tag ])), tag.span(aside) ])
    else
      safe_join([ tag.span(label), pct_tag ])
    end

    tag.div(class: "service-bar") do
      safe_join([
        tag.div(label_row, class: "service-bar__label"),
        tag.div(class: "progress", role: "progressbar", aria: { label: label, valuemin: 0, valuemax: 100, valuenow: pct }) do
          tag.div(class: [ "progress-bar", color_class ], style: "width: #{pct.clamp(0, 100)}%")
        end
      ])
    end
  end

  def purchase_status_badge_class(status)
    case status
    when "A" then "bg-success"
    when "P" then "bg-info text-dark"
    when "S" then "bg-warning text-dark"
    when "C" then "bg-danger"
    else           "bg-secondary"
    end
  end

  # Badge for a Fliip record that Fliip no longer returns; nothing otherwise.
  def missing_from_fliip_badge(record)
    return unless record&.missing_from_fliip?

    content_tag(:span, "Retiré de Fliip", class: "badge bg-dark",
                title: "Absent de Fliip depuis le #{record.missing_from_fliip_at.strftime('%d/%m/%Y')}")
  end

  def svc_time_range_label(svc)
    sd = svc.start_date&.strftime("%d/%m/%Y")
    ed = svc.expire_date&.strftime("%d/%m/%Y")
    return "#{sd}–#{ed}" if sd && ed
    return "#{sd}–?"     if sd
    return "?–#{ed}"     if ed
    "—"
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
