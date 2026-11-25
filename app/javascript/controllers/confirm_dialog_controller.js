import { Controller } from "@hotwired/stimulus"

// Saisir: asks before saving a séance, in a native <dialog>, one question at a
// time: first when the date is outside the service's dates, then when the
// client is absent (an absence is used, or -24h: a séance is deducted). The
// texts come from SessionsHelper, as data attributes on the dialog; the
// absence wording is read from the ticket so it matches what it shows.
// In a séance's edit card (fixedService) only the absence is asked, and only
// when the edit makes a present séance absent (wasAbsent false).
export default class extends Controller {
  static targets = ["form", "dialog", "title", "body", "confirmButton", "cancelButton", "date"]
  static values = { fixedService: Boolean, wasAbsent: Boolean }

  check(event) {
    if (this.confirmed) {
      this.confirmed = false
      return
    }

    this.pending = [this.#outsideServiceDates(), this.#absence()].filter(Boolean)
    if (this.pending.length === 0) return

    event.preventDefault()
    this.submitter = event.submitter
    this.#ask(this.pending.shift())
  }

  confirm() {
    this.dialogTarget.close()
    if (this.pending && this.pending.length > 0) {
      this.#ask(this.pending.shift())
      return
    }
    this.confirmed = true
    const form = this.hasFormTarget ? this.formTarget : this.element
    form.requestSubmit(this.submitter)
  }

  cancel() {
    this.pending = []
    this.dialogTarget.close()
  }

  #ask({ title, body, confirmLabel, cancelLabel }) {
    this.titleTarget.textContent = title
    this.bodyTarget.textContent = body
    this.confirmButtonTarget.textContent = confirmLabel
    this.cancelButtonTarget.textContent = cancelLabel
    this.dialogTarget.showModal()
  }

  // ISO dates compare as strings.
  #outsideServiceDates() {
    const service = this.#checked("session[fliip_service_id]")
    const date = this.hasDateTarget ? this.dateTarget.value : ""
    if (!service || !date) return null

    const d = this.dialogTarget.dataset
    const { startDate, endDate } = service.dataset
    let key = null
    if (startDate && date < startDate) key = "beforeStart"
    else if (endDate && date > endDate) key = "afterEnd"
    if (!key) return null

    return { title: d[`${key}Title`], body: d[`${key}Body`], confirmLabel: d.continueLabel, cancelLabel: d.cancelLabel }
  }

  #absence() {
    if (this.#checked("session[present]")?.value !== "0") return null
    if (this.fixedServiceValue) {
      if (this.wasAbsentValue) return null
    } else if (!this.#checked("session[fliip_service_id]")) {
      return null
    }

    const d = this.dialogTarget.dataset
    const moins24 = this.element.querySelector("[data-seance-outcome-target='moins24Alert']")
    const body = moins24 && !moins24.hidden
      ? d.moins24Body
      : `${d.absenceBody} ${this.element.querySelector("[data-seance-outcome-target='absenceLine']")?.textContent.trim() || ""}`.trim()

    return { title: d.absenceTitle, body, confirmLabel: d.absenceConfirmLabel, cancelLabel: d.absenceCancelLabel }
  }

  #checked(name) {
    return this.element.querySelector(`input[name="${name}"]:checked`)
  }
}
