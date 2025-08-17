import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["section"]

  toggle() {
    this.sectionTargets.forEach((el) => {
      el.classList.toggle("d-none")
    })
  }
}
