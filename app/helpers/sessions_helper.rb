module SessionsHelper
  def default_time_slot_str(now: Time.zone.now)
    now   = now.change(sec: 0)
    mins  = now.min >= 30 ? 30 : 0
    slot  = now.change(min: mins)

    day_start = now.change(hour: 6,  min: 0)
    day_last  = now.change(hour: 20, min: 30)

    slot = day_start if slot < day_start
    slot = day_last  if slot > day_last

    slot.strftime("%H:%M")
  end

  def sessions_modal_primary_label
    "Continuer"
  end

  def sessions_modal_secondary_label
    "Annuler"
  end

  def sessions_modal_absence_free_title
    "Confirmer l’absence"
  end

  def sessions_modal_absence_free_body
    "Procéder à l’utilisation d’une absence sans frais?"
  end

  def sessions_modal_absence_paid_title
    "Confirmer l’absence"
  end

  def sessions_modal_absence_paid_body
    "Solde d’absences sans frais épuisé. Procéder à la déduction d’une séance de son forfait?"
  end

  def sessions_modal_delete_title(session)
    "Supprimer la séance"
  end

  def sessions_modal_delete_body(session)
    # Customize with labels if you like:
    # "Supprimer la séance du #{session.occurred_at&.strftime('%d/%m/%Y %H:%M')} pour #{session.fliip_user&.full_name} ?"
    "Es-tu sûr·e de vouloir supprimer cette séance ? Cette action est irréversible."
  end

  def sessions_modal_delete_primary_label
    "Supprimer"
  end

  def sessions_modal_delete_secondary_label
    "Annuler"
  end
end
