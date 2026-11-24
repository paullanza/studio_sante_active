# Status badges for services and abonnements on the new layout (docs/ui.md).
# A badge always carries its label, never the colour alone.
module ServiceBadgesHelper
  SERVICE_STATUS_BADGES = {
    "A" => "badge--chargee",
    "P" => "badge--planned",
    "S" => "badge--warning"
  }.freeze

  CONTRACT_STATUS_BADGES = {
    "A" => "badge--chargee",
    "S" => "badge--warning"
  }.freeze

  def service_status_badge(svc)
    if svc.removed_from_fliip?
      status_badge("Retiré de Fliip", "badge--retire")
    elsif svc.paid_allowed_total.positive? && svc.fully_used?
      status_badge("Toutes les séances utilisées", "badge--neutral")
    elsif svc.purchase_status == "A" && service_ended?(svc)
      # Fliip still says active, but the end date has passed.
      status_badge("Terminé", "badge--neutral")
    else
      status_badge(svc.status_name || "Inconnu", SERVICE_STATUS_BADGES.fetch(svc.purchase_status, "badge--neutral"))
    end
  end

  # How a service card or row looks: :active, :planned or :suspended get a
  # coloured stripe; :done (inactive, cancelled, ended, all séances used or
  # removed from Fliip) is muted, so finished services are easy to skip.
  def service_row_state(svc, today: Date.current)
    return :done if svc.removed_from_fliip? || %w[I C].include?(svc.purchase_status)
    return :done if svc.paid_allowed_total.positive? && svc.fully_used?
    return :done if service_ended?(svc, today: today)

    { "A" => :active, "P" => :planned, "S" => :suspended }.fetch(svc.purchase_status, :done)
  end

  def contract_status_badge(contract)
    if contract.missing_from_fliip? || contract.fliip_user&.missing_from_fliip?
      status_badge("Retiré de Fliip", "badge--retire")
    else
      status_badge(contract.status_name, CONTRACT_STATUS_BADGES.fetch(contract.status, "badge--neutral"))
    end
  end

  private

  def service_ended?(svc, today: Date.current)
    svc.expire_date.present? && svc.expire_date < today
  end

  def status_badge(label, modifier)
    tag.span(label, class: [ "badge", modifier ])
  end
end
