# app/helpers/consultations_helper.rb
module ConsultationsHelper
  # ==========================================================
  # DELETE MODAL
  # ==========================================================
  def consultations_modal_delete_title(_consultation)
    "Supprimer la consultation"
  end

  def consultations_modal_delete_body(_consultation)
    "Es-tu sûr·e de vouloir supprimer cette consultation ? Cette action est irréversible."
  end

  def consultations_modal_delete_primary_label
    "Supprimer"
  end

  def consultations_modal_delete_secondary_label
    "Annuler"
  end

  # ==========================================================
  # DISASSOCIATE (CONFIRM MODAL)
  # ==========================================================
  def consultations_modal_disassociate_title(_consultation)
    "Retirer l’association"
  end

  def consultations_modal_disassociate_body(consultation)
    # Prefer explicit associations, with safe fallbacks
    service = consultation&.fliip_service
    client  = consultation&.fliip_user || service&.fliip_user

    # Build readable parts
    client_str =
      if client.present?
        "#{client.user_firstname} #{client.user_lastname}".strip
      else
        nil
      end

    service_str =
      if service.present?
        service.service_name.presence || "Service ##{service.id}"
      else
        nil
      end

    # Compose message based on what we actually have
    label =
      if client_str && service_str
        "#{client_str} – #{service_str}"
      elsif client_str
        client_str
      else
        "cette association"
      end

    "Retirer l’association avec « #{label} » ?"
  end

  def consultations_modal_disassociate_primary_label
    "Retirer"
  end

  def consultations_modal_disassociate_secondary_label
    "Annuler"
  end
end
