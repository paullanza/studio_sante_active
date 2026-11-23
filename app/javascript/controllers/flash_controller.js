import { Controller } from "@hotwired/stimulus"

// Flash message on the new layout: removed when closed, or after
// `timeout` ms when it is above 0 (notices only; alerts stay).
export default class extends Controller {
  static values = { timeout: Number }

  connect() {
    if (this.timeoutValue > 0) {
      this.timer = setTimeout(() => this.dismiss(), this.timeoutValue)
    }
  }

  disconnect() {
    clearTimeout(this.timer)
  }

  dismiss() {
    this.element.remove()
  }
}
