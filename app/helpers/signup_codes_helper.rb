module SignupCodesHelper
  # A code's status as a badge: Actif, Utilisé par …, Expiré or Désactivé.
  def signup_code_status(code)
    case code.status
    when "active"
      code.expired_by_time? ? tag.span("Expiré", class: "badge badge--neutral") : tag.span("Actif", class: "badge badge--chargee")
    when "used"
      name = code.used_by&.full_name.presence || code.used_by&.email
      tag.span(name ? "Utilisé par #{name}" : "Utilisé", class: "badge badge--neutral")
    when "expired"
      tag.span("Expiré", class: "badge badge--neutral")
    when "deactivated"
      tag.span("Désactivé", class: "badge badge--neutral")
    end
  end
end
