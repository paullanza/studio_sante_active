import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    autohide: { type: Boolean, default: true },
    delay: { type: Number, default: 5000 }
  }

  connect() {
    // Uses Bootstrap bundle loaded via CDN (window.bootstrap)
    this.toast = window.bootstrap.Toast.getOrCreateInstance(this.element, {
      autohide: this.autohideValue,
      delay: this.delayValue
    })
    this.toast.show()
  }

  disconnect() {
    if (this.toast) this.toast.hide()
  }
}
