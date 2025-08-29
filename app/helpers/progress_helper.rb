module ProgressHelper
  # Default colors:
  # - Blue most of the time
  # - Grey (secondary) at 100%
  def progress_base_color(percent)
    percent.to_i >= 100 ? 'bg-secondary' : 'bg-primary'
  end

  # Discrepancy colors for "sessions used" vs "time progress":
  # If sessions is 15–24% lower → yellow
  # 25–39% lower → orange
  # 40%+ lower   → red
  def progress_discrepancy_color(sessions_pct, time_pct)
    diff = time_pct.to_i - sessions_pct.to_i
    return nil if diff < 15

    case diff
    when 15..24 then 'bg-warning'
    when 25..39 then 'bg-orange'
    else             'bg-danger'
    end
  end

  # Final color for the sessions bar: discrepancy color if any, otherwise base.
  def progress_usage_color(sessions_pct, time_pct)
    progress_discrepancy_color(sessions_pct, time_pct) || progress_base_color(sessions_pct)
  end

  # Reusable thin progress with centered overlay label (always readable).
  # Usage: <%= bar_with_label(percent: 42, label: "…", bg_class: "bg-primary") %>
  def bar_with_label(percent:, label:, bg_class: nil)
    bg_class ||= progress_base_color(percent)
    # Ensure text is readable over the fill; grey/yellow/orange use dark text.
    dark_tone_bgs = %w[bg-warning bg-orange bg-secondary]
    tone = dark_tone_bgs.include?(bg_class) ? 'label-dark' : 'label-light'

    content_tag :div,
      class: "progress progress-thin progress-with-label progress-dark-bg",
      role: "progressbar",
      aria: { valuemin: 0, valuemax: 100, valuenow: percent.to_i } do

      concat content_tag(:div, "", class: "progress-bar #{bg_class}", style: "width:#{percent.to_i}%")
      concat content_tag(:div, label, class: "progress-label #{tone}")
    end
  end
end
