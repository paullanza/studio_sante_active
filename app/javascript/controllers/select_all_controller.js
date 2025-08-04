import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["checkbox", "checkboxItem"]

  toggleAll(event) {
    const checked = event.target.checked
    this.checkboxItemTargets.forEach(cb => cb.checked = checked)
  }
}
