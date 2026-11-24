# Status badges for services and abonnements on the new layout (docs/ui.md).
# A badge always carries its label, never the colour alone.
module ServiceBadgesHelper
  SERVICE_STATUS_BADGES = {
    "A" => "badge--chargee",
    "P" => "badge--absence",
    "S" => "badge--moins24"
  }.freeze

  CONTRACT_STATUS_BADGES = {
    "A" => "badge--chargee",
    "S" => "badge--moins24"
  }.freeze

  def service_status_badge(svc)
    if svc.removed_from_fliip?
      status_badge("Retiré de Fliip", "badge--retire")
    elsif svc.paid_allowed_total.positive? && svc.fully_used?
      status_badge("Toutes les séances utilisées", "badge--neutral")
    else
      status_badge(svc.status_name || "Inconnu", SERVICE_STATUS_BADGES.fetch(svc.purchase_status, "badge--neutral"))
    end
  end

  def contract_status_badge(contract)
    if contract.missing_from_fliip? || contract.fliip_user&.missing_from_fliip?
      status_badge("Retiré de Fliip", "badge--retire")
    else
      status_badge(contract.status_name, CONTRACT_STATUS_BADGES.fetch(contract.status, "badge--neutral"))
    end
  end

  private

  def status_badge(label, modifier)
    tag.span(label, class: [ "badge", modifier ])
  end
end
