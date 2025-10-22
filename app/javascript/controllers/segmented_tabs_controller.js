// app/javascript/controllers/segmented_tabs_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tab", "pane", "slider"]
  static values = { active: String }

  connect() {
    this.activateTo(this.activeValue || (this.tabTargets[0]?.dataset.value || "session"))
  }

  activate(event) {
    const value = event.currentTarget.dataset.value
    this.activateTo(value)
  }

  activateTo(value) {
    this.activeValue = value
    this.paneTargets.forEach(p => {
      p.classList.toggle("d-none", p.dataset.value !== value)
    })
    this.tabTargets.forEach((btn, idx) => {
      const active = btn.dataset.value === value
      btn.classList.toggle("btn-primary", active)
      btn.classList.toggle("btn-light", !active)
      if (this.hasSliderTarget && active) {
        const width = 100 / this.tabTargets.length
        this.sliderTarget.style.left = `${idx * width + 4}px`
        this.sliderTarget.style.width = `calc(${width}% - 8px)`
      }
    })
  }
}
