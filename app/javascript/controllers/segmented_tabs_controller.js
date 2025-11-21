// app/javascript/controllers/segmented_tabs_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tab", "pane", "slider"]
  static values = { active: String }

  connect() {
    this._onResize = this.positionSlider.bind(this)
    window.addEventListener("resize", this._onResize)

    const initial = this.activeValue || (this.tabTargets[0]?.dataset.value || "session")
    this.activateTo(initial)
  }

  disconnect() {
    window.removeEventListener("resize", this._onResize)
  }

  activate(event) {
    const value = event.currentTarget.dataset.value
    this.activateTo(value)
  }

  activateTo(value) {
    this.activeValue = value

    // Toggle panes
    this.paneTargets.forEach(p => {
      p.classList.toggle("d-none", p.dataset.value !== value)
    })

    // Toggle tab button styles
    this.tabTargets.forEach(btn => {
      const active = btn.dataset.value === value
      btn.classList.toggle("btn-primary", active)
      btn.classList.toggle("btn-light", !active)
      btn.setAttribute("aria-selected", active ? "true" : "false")
    })

    if (this.hasSliderTarget) {
      // Wait a frame so layout is up-to-date, then position
      window.requestAnimationFrame(() => this.positionSlider())
    }
  }

  positionSlider() {
    if (!this.hasSliderTarget) return
    const activeBtn =
      this.tabTargets.find(b => b.dataset.value === this.activeValue) || this.tabTargets[0]
    if (!activeBtn) return

    const container = this.sliderTarget.parentElement // the .position-relative tab container
    const cRect = container.getBoundingClientRect()
    const bRect = activeBtn.getBoundingClientRect()

    const left = bRect.left - cRect.left + container.scrollLeft
    const width = bRect.width

    this.sliderTarget.style.left = `${left}px`
    this.sliderTarget.style.width = `${width}px`
  }
}
