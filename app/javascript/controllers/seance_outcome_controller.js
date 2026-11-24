import { Controller } from "@hotwired/stimulus"

// Saisir: shows what the séance will be recorded as (Chargée, Absence or
// -24h) as the service, presence and duration change. Mirrors
// SessionsHelper#seance_outcome_preview, which renders the same state on the
// server; the server still validates.
export default class extends Controller {
  static targets = ["badge", "absenceLine", "moins24Alert", "noneLeft", "submit", "submitLabel"]

  static LABELS = { chargee: "Chargée", absence: "Absence", moins24: "-24h" }
  static SUBMIT = "Enregistrer la séance"
  static SUBMIT_MOINS24 = "Enregistrer : -24h, séance déduite"

  connect() {
    this.update()
  }

  update() {
    const service = this.#checked("session[fliip_service_id]")
    const present = this.#checked("session[present]")?.value !== "0"
    const duration = parseFloat(this.#checked("session[duration]")?.value || "1")

    if (!service) {
      this.#show(null, 0, false)
      return
    }

    const free = parseFloat(service.dataset.freeRemaining || "0")
    const paidRaw = service.dataset.paidRemaining
    // No allocation: the quota isn't enforced (Session#respect_quota_limits).
    const paid = paidRaw === "" || paidRaw === undefined ? Infinity : parseFloat(paidRaw)

    const outcome = present ? "chargee" : (free >= duration ? "absence" : "moins24")
    const needed = outcome === "absence" ? free : paid
    this.#show(outcome, free - duration, needed < duration, duration)
  }

  #show(outcome, absencesAfter, noneLeft, duration = 1) {
    const badge = this.badgeTarget
    badge.classList.remove("badge--chargee", "badge--absence", "badge--moins24", "badge--neutral")
    badge.classList.add(outcome ? `badge--${outcome}` : "badge--neutral")
    badge.textContent = outcome ? this.constructor.LABELS[outcome] : "Choisissez un service"

    this.absenceLineTarget.hidden = outcome !== "absence"
    if (outcome === "absence") {
      const left = this.#count(absencesAfter)
      this.absenceLineTarget.textContent =
        `Utilise ${this.#count(duration)} absence · ${left} ${absencesAfter < 2 ? "restante" : "restantes"} après celle-ci`
    }

    this.moins24AlertTarget.hidden = outcome !== "moins24"
    this.submitLabelTarget.textContent = outcome === "moins24" ? this.constructor.SUBMIT_MOINS24 : this.constructor.SUBMIT

    this.noneLeftTarget.hidden = !noneLeft
    this.submitTarget.disabled = noneLeft
  }

  // « 1 », « 0,5 » (CountsHelper#format_count).
  #count(value) {
    return String(Math.round(value * 100) / 100).replace(".", ",")
  }

  #checked(name) {
    return this.element.querySelector(`input[name="${name}"]:checked`)
  }
}
