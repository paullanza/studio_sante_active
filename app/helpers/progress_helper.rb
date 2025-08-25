module ProgressHelper
  # Map % → Bootstrap color classes
  # <50 green, 50-74 yellow, 75-94 orange, 95-99 red, 100 blue
  def progress_palette(percent)
    p = percent.to_i.clamp(0, 100)

    case p
    when 100..100 then ['bg-primary', :light] # blue
    when 95..99   then ['bg-danger',  :light] # red
    when 75..94   then ['bg-orange',  :dark]  # orange
    when 50..74   then ['bg-warning', :dark]  # yellow
    else               ['bg-success', :light] # green
    end
  end

  # Reusable thin progress with centered overlay label (always readable).
  # Usage: <%= bar_with_label(percent: 42, label: "…") %>
  def bar_with_label(percent:, label:, bg_class: nil)
    bg_class ||= progress_palette(percent).first
    tone      = (bg_class.in?(%w[bg-warning bg-orange]) ? 'label-dark' : 'label-light')

    content_tag :div,
      class: "progress progress-thin progress-with-label progress-dark-bg",
      role: "progressbar",
      aria: { valuemin: 0, valuemax: 100, valuenow: percent.to_i } do

      concat content_tag(:div, "", class: "progress-bar #{bg_class}", style: "width:#{percent.to_i}%")
      concat content_tag(:div, label, class: "progress-label #{tone}")
    end
  end
end
