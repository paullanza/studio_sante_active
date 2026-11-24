# Helpers for the new layout (layouts/studio): the back link that replaces
# header bands, the top nav tabs and inline SVG icons. See docs/ui.md.
module LayoutHelper
  # Stroke icons from the approved mockups (docs/design), 24 × 24 viewBox.
  NAV_ICONS = {
    "dashboard" => "M3 11l9-8 9 8M5 10v10h14V10",
    "clients" => "M16 20v-2a4 4 0 0 0-8 0v2M12 12a4 4 0 1 0 0-8 4 4 0 0 0 0 8z",
    "saisir" => "M12 5v14M5 12h14",
    "mes_services" => "M4 6h16M4 12h16M4 18h10",
    "plus" => "M5 12h.01M12 12h.01M19 12h.01"
  }.freeze
  BACK_ICON = "M15 18l-6-6 6-6".freeze
  NEXT_ICON = "M9 18l6-6-6-6".freeze
  ARROW_ICON = "M5 12h14M13 6l6 6-6 6".freeze
  REFRESH_ICON = "M21 12a9 9 0 1 1-3-6.7L21 8M21 3v5h-5".freeze
  PHONE_ICON = "M22 16.9v3a2 2 0 0 1-2.2 2 19.8 19.8 0 0 1-8.6-3.1 19.5 19.5 0 0 1-6-6A19.8 19.8 0 0 1 2.1 4.2 2 2 0 0 1 4.1 2h3a2 2 0 0 1 2 1.7c.1.9.4 1.8.7 2.7a2 2 0 0 1-.5 2.1L8 9.8a16 16 0 0 0 6 6l1.3-1.3a2 2 0 0 1 2.1-.4c.9.3 1.8.6 2.7.7a2 2 0 0 1 1.7 2z".freeze
  MAIL_ICON = "M4 4h16v16H4zM4 6l8 7 8-7".freeze

  # Where the GEKO brand links: the user's landing page, or sign in.
  def home_path
    user_signed_in? ? dashboard_path_for(current_user) : new_user_session_path
  end

  # The small « ← Label » link at the top of a page.
  def back_link_to(label, path)
    link_to path, class: "back-link" do
      safe_join([ icon_svg(BACK_ICON, size: 18, stroke_width: 2.2), label ])
    end
  end

  # A top nav tab. It is active when the page declared the same section with
  # content_for(:nav_section, "clients").
  def nav_tab_to(label, path, section)
    active = nav_section_active?(section)
    link_to path, class: class_names("nav-tab", "is-active" => active), aria: { current: (active ? "page" : nil) } do
      safe_join([ nav_icon(section), tag.span(label, class: "nav-tab__label") ])
    end
  end

  def nav_section_active?(section)
    content_for(:nav_section).to_s == section.to_s
  end

  def nav_icon(section)
    icon_svg(NAV_ICONS.fetch(section.to_s), size: 22)
  end

  # Decorative inline SVG drawn with the current text colour.
  # The arrow a forward button carries after its label; it slides on hover.
  #   link_to new_seance_path, class: "btn btn--primary" do
  #     safe_join([ "Saisir une séance", button_arrow ])
  #   end
  def button_arrow
    tag.span(icon_svg(ARROW_ICON, size: 18, stroke_width: 2.4), class: "btn__arrow")
  end

  def icon_svg(path_data, size: 24, stroke_width: 2)
    tag.svg(
      tag.path(d: path_data),
      width: size, height: size, "viewBox" => "0 0 24 24", fill: "none",
      stroke: "currentColor", "stroke-width" => stroke_width,
      "stroke-linecap" => "round", "stroke-linejoin" => "round",
      "aria-hidden" => "true", focusable: "false"
    )
  end
end
