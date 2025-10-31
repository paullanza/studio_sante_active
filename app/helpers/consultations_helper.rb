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
  # ALREADY ASSOCIATED (INFO MODAL)
  # ==========================================================
  def consultations_modal_already_associated_title(_consultation)
    "Association déjà présente"
  end

  def consultations_modal_already_associated_body(consultation)
    service = consultation.fliip_service
    name = service&.service_name.presence || "Service ##{service&.id}"
    "Cette consultation est déjà associée à « #{name} ». Pour changer, retire d’abord l’association."
  end

  def consultations_modal_already_associated_primary_label
    "OK"
  end

  def consultations_modal_already_associated_secondary_label
    "Fermer"
  end


  # ==========================================================
  # DISASSOCIATE (CONFIRM MODAL)
  # ==========================================================
  def consultations_modal_disassociate_title(_consultation)
    "Retirer l’association"
  end

  def consultations_modal_disassociate_body(consultation)
    service = consultation.fliip_service
    client = consultation.fliip_service.fliip_user
    name = service&.service_name.presence || "Service ##{service&.id}"
    "Retirer l’association avec « #{client.user_firstname} #{client.user_lastname} - #{name} » ?"
  end

  def consultations_modal_disassociate_primary_label
    "Retirer"
  end

  def consultations_modal_disassociate_secondary_label
    "Annuler"
  end
end
