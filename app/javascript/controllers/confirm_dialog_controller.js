import { Controller } from "@hotwired/stimulus"

// Saisir: asks for confirmation in a native <dialog> before saving a séance
// dated before its service's start or after its end. The texts come from
// SessionsHelper, as data attributes on the dialog.
export default class extends Controller {
  static targets = ["form", "dialog", "title", "body", "date"]

  check(event) {
    if (this.confirmed) {
      this.confirmed = false
      return
    }

    const key = this.#outsideServiceDates()
    if (!key) return

    event.preventDefault()
    this.submitter = event.submitter
    this.titleTarget.textContent = this.dialogTarget.dataset[`${key}Title`]
    this.bodyTarget.textContent = this.dialogTarget.dataset[`${key}Body`]
    this.dialogTarget.showModal()
  }

  confirm() {
    this.dialogTarget.close()
    this.confirmed = true
    const form = this.hasFormTarget ? this.formTarget : this.element
    form.requestSubmit(this.submitter)
  }

  cancel() {
    this.dialogTarget.close()
  }

  // "beforeStart", "afterEnd" or null. ISO dates compare as strings.
  #outsideServiceDates() {
    const service = this.element.querySelector('input[name="session[fliip_service_id]"]:checked')
    const date = this.hasDateTarget ? this.dateTarget.value : ""
    if (!service || !date) return null

    const { startDate, endDate } = service.dataset
    if (startDate && date < startDate) return "beforeStart"
    if (endDate && date > endDate) return "afterEnd"
    return null
  }
}
