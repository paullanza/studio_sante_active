import { Controller } from "@hotwired/stimulus"

// Saisir: shows what the séance will be recorded as (Présent·e, Absence or
// -24h) as the service, presence and duration change. Mirrors
// SessionsHelper#seance_outcome_preview, which renders the same state on the
// server; the server still validates. In a séance's edit card there is no
// service to choose: the remaining counts (this séance's own usage given back)
// and the button label come as values instead.
export default class extends Controller {
  static targets = ["badge", "absenceLine", "moins24Alert", "noneLeft", "submit", "submitLabel"]
  static values = { freeRemaining: Number, paidRemaining: Number, submitLabel: String }

  static LABELS = { chargee: "Présent·e", absence: "Absence", moins24: "-24h" }
  static SUBMIT = "Enregistrer la séance"
  static SUBMIT_MOINS24 = "Enregistrer : -24h, séance déduite"

  connect() {
    this.update()
  }

  update() {
    const service = this.#checked("session[fliip_service_id]") || this.#fixedService()
    const present = this.#checked("session[present]")?.value !== "0"
    const duration = parseFloat(this.#checked("session[duration]")?.value || "1")

    if (!service) {
      this.#show(null, 0, false)
      return
    }

    const free = parseFloat(service.dataset.freeRemaining || "0")
    const paid = parseFloat(service.dataset.paidRemaining || "0")

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
    const submit = this.hasSubmitLabelValue ? this.submitLabelValue : this.constructor.SUBMIT
    this.submitLabelTarget.textContent = outcome === "moins24" ? this.constructor.SUBMIT_MOINS24 : submit

    this.noneLeftTarget.hidden = !noneLeft
    this.submitTarget.disabled = noneLeft
  }

  // The edit card's counts, shaped like a service radio's dataset.
  #fixedService() {
    if (!this.hasFreeRemainingValue) return null

    return { dataset: { freeRemaining: this.freeRemainingValue, paidRemaining: this.paidRemainingValue } }
  }

  // « 1 », « 0,5 » (CountsHelper#format_count).
  #count(value) {
    return String(Math.round(value * 100) / 100).replace(".", ",")
  }

  #checked(name) {
    return this.element.querySelector(`input[name="${name}"]:checked`)
  }
}
