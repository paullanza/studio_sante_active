module SessionsHelper
  OUTCOME_BADGE_CLASSES = { chargee: "badge--chargee", moins24: "badge--moins24", absence: "badge--absence" }.freeze

  # The badge modifier for a séance's outcome (Chargée, -24h, Absence).
  def outcome_badge_class(session)
    OUTCOME_BADGE_CLASSES.fetch(session.outcome)
  end

  # « ven. 13/11/2026 · 17 h 00 », with French day names from config/locales/fr.yml.
  def seance_datetime(time)
    return "—" unless time

    l(time, format: "%a %d/%m/%Y · %H h %M")
  end

  # « Non confirmée » for a séance or consultation awaiting payroll, else
  # « Confirmée le dd/mm/yyyy ».
  def confirmation_status(record)
    unless record.confirmed
      return tag.span("Non confirmée", class: "text-unconfirmed")
    end

    label = record.confirmed_at ? "Confirmée le #{l(record.confirmed_at.to_date)}" : "Confirmée"
    tag.span(label, class: "text-muted")
  end

  SUBMIT_LABELS = { moins24: "Enregistrer : -24h, séance déduite" }.freeze

  # What the booking form shows above its button for the chosen service,
  # presence and duration: the outcome, the absences left after this one, and
  # whether the service has run out of what this séance needs. Mirrors
  # Session#set_session_type_and_duration and respect_quota_limits;
  # seance_outcome_controller.js does the same in the browser. Nil outcome
  # without a service. `editing: true` (the edit card) gives the séance's own
  # usage back, as Session#recalculate_type does.
  def seance_outcome_preview(session, editing: false)
    service = session.fliip_service
    return { outcome: nil, duration: 1.0, absences_after: nil, none_left: false, submit_label: "Enregistrer la séance" } unless service

    duration = Session::DURATIONS.include?(session.duration.to_f) ? session.duration.to_f : 1.0
    free_left, paid_left = seance_left(session, editing:)
    outcome =
      if session.present then :chargee
      elsif free_left >= duration then :absence
      else :moins24
      end
    needed_left = outcome == :absence ? free_left : paid_left

    {
      outcome: outcome,
      duration: duration,
      free_left: free_left,
      paid_left: paid_left,
      absences_after: (free_left - duration if outcome == :absence),
      none_left: !service.allocation_to_define? && needed_left < duration,
      submit_label: SUBMIT_LABELS.fetch(outcome, editing ? "Enregistrer" : "Enregistrer la séance")
    }
  end

  # [absences left, paid séances left] for the preview. With the allocation
  # still « à définir » there are no absences and no paid limit (the model
  # charges the séance and skips the quota check).
  def seance_left(session, editing:)
    service = session.fliip_service
    return [ 0.0, Float::INFINITY ] if service.allocation_to_define?
    return [ session.free_left_excluding_self, session.paid_left_excluding_self ] if editing

    [ service.remaining_free_sessions.to_f, service.remaining_paid_sessions.to_f ]
  end

  # « Utilise 1 absence · 1 restante après celle-ci ».
  def absence_use_line(duration, absences_after)
    left = absences_after.to_f
    "Utilise #{format_count(duration)} absence · #{format_count(left)} #{left < 2 ? 'restante' : 'restantes'} après celle-ci"
  end

  # The ticket's day, « mar. 24 nov. », from an ISO date (form_summary_controller.js
  # writes the same). Blank when the date can't be read.
  def ticket_day(iso_date)
    l(Date.iso8601(iso_date.to_s), format: "%a %-d %b")
  rescue Date::Error
    ""
  end

  # « 17 h 00 » from « 17:00 ».
  def ticket_time(hhmm)
    hhmm.to_s.sub(":", " h ")
  end

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

  # Asked before saving a séance where the client was absent.
  def sessions_modal_absence_title
    "Confirmer l'absence"
  end

  def sessions_modal_absence_body
    "Cette séance sera enregistrée comme une absence."
  end

  def sessions_modal_moins24_body
    "Aucune absence restante : cette séance sera enregistrée comme -24h et déduite du forfait."
  end

  def sessions_modal_absence_confirm_label
    "Confirmer l'absence"
  end

  def sessions_modal_absence_cancel_label
    "Revenir"
  end

  def sessions_modal_before_start_title
    "Séance avant le début du service"
  end

  def sessions_modal_before_start_body
    "La date choisie est avant la date de début du service. Veux-tu vraiment continuer?"
  end

  def sessions_modal_after_end_title
    "Séance après la fin du service"
  end

  def sessions_modal_after_end_body
    "La date choisie est après la date de fin du service. Veux-tu vraiment continuer?"
  end

  def sessions_modal_delete_title(session)
    "Supprimer la séance"
  end

  def sessions_modal_delete_body(session)
    "Es-tu sûr·e de vouloir supprimer cette séance ? Cette action est irréversible."
  end

  def sessions_modal_delete_primary_label
    "Supprimer"
  end

  def sessions_modal_delete_secondary_label
    "Annuler"
  end
end
