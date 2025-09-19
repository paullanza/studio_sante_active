import { Controller } from "@hotwired/stimulus"

// Simple tabs: toggles d-none on panels, manages .active + aria-selected on buttons.
export default class extends Controller {
  connect() {
    this.buttons = Array.from(this.element.querySelectorAll('[role="tab"]'))
    // Panels are within the same controller scope (nav header + card body wrapper)
    this.panes   = Array.from(this.element.querySelectorAll('[role="tabpanel"]'))

    const activeBtn = this.buttons.find(b => b.classList.contains("active")) || this.buttons[0]
    if (activeBtn) this.showFor(activeBtn)
  }

  activate(event) {
    event.preventDefault()
    this.showFor(event.currentTarget)
  }

  showFor(button) {
    const targetSelector = button.getAttribute("data-bs-target")
    if (!targetSelector) return

    // Update buttons
    this.buttons.forEach(b => {
      const isActive = b === button
      b.classList.toggle("active", isActive)
      b.setAttribute("aria-selected", isActive ? "true" : "false")
    })

    // Toggle panels using d-none only (no Bootstrap tab-pane classes involved)
    this.panes.forEach(p => {
      const shouldShow = `#${p.id}` === targetSelector
      p.classList.toggle("d-none", !shouldShow)
    })
  }
}
