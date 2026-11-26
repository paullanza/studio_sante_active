import { Controller } from "@hotwired/stimulus"

// Confirmations, « À confirmer »: « Tout sélectionner » for the page and per
// trainer group (data-group), and the gold button's count. Rows can be
// swapped by their Turbo frame (in-place edit), so targets are read live and
// one delegated change listener keeps everything in step.
export default class extends Controller {
  static targets = ["item", "group", "all", "count", "submit"]

  connect() {
    this.refresh()
  }

  changed(event) {
    const box = event.target
    if (this.allTargets.includes(box)) {
      this.itemTargets.forEach((item) => { item.checked = box.checked })
    } else if (this.groupTargets.includes(box)) {
      this.itemsOf(box.dataset.group).forEach((item) => { item.checked = box.checked })
    }
    this.refresh()
  }

  // Called after a frame swap too (an edited row comes back unchecked).
  itemTargetConnected() { this.refresh() }
  itemTargetDisconnected() { this.refresh() }

  refresh() {
    const checked = this.itemTargets.filter((item) => item.checked).length
    if (this.hasCountTarget) this.countTarget.textContent = checked
    if (this.hasSubmitTarget) this.submitTarget.disabled = checked === 0

    this.groupTargets.forEach((group) => this.mirror(group, this.itemsOf(group.dataset.group)))
    if (this.hasAllTarget) this.mirror(this.allTarget, this.itemTargets)
  }

  mirror(toggle, items) {
    const checked = items.filter((item) => item.checked).length
    toggle.checked = items.length > 0 && checked === items.length
    toggle.indeterminate = checked > 0 && checked < items.length
  }

  itemsOf(group) {
    return this.itemTargets.filter((item) => item.dataset.group === group)
  }
}
