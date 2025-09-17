import { Controller } from "@hotwired/stimulus"

// Reusable, dead-simple tab switcher.
// Conventions:
// - data-controller="tabs"
// - data-tabs-target="tab" on each tab trigger (e.g., button.nav-link)
// - data-tabs-target="panel" on each content panel
// - Pair via matching data-key values, e.g. data-key="services"
//
// Optional values:
// - data-tabs-active-class-value="active" (default: "active")
// - data-tabs-hidden-class-value="d-none" (default: "d-none")
// - data-tabs-remember-value="true" to sync with location.hash (default: true)

export default class extends Controller {
  static targets = ["tab", "panel"]
  static values = {
    activeClass: { type: String, default: "active" },
    hiddenClass: { type: String, default: "d-none" },
    remember:    { type: Boolean, default: true }
  }

  connect() {
    // Try to activate from hash, else first tab.
    if (!this.activateFromHash()) {
      const first = this.tabTargets[0]
      if (first) this.activate(first)
    }

    // Support back/forward navigation if remembering.
    if (this.rememberValue) {
      this._onPopState = () => this.activateFromHash()
      window.addEventListener("popstate", this._onPopState)
    }
  }

  disconnect() {
    if (this._onPopState) {
      window.removeEventListener("popstate", this._onPopState)
    }
  }

  select(event) {
    this.activate(event.currentTarget)
  }

  // ----- internal

  activateFromHash() {
    if (!this.rememberValue) return false
    const key = (window.location.hash || "").replace(/^#/, "")
    if (!key) return false
    const tab = this.tabTargets.find(t => this.keyFor(t) === key)
    if (tab) {
      this.activate(tab, { pushHash: false })
      return true
    }
    return false
  }

  activate(tabEl, { pushHash = true } = {}) {
    const key = this.keyFor(tabEl)
    if (!key) return

    // Deactivate all tabs/panels
    this.tabTargets.forEach(t => {
      t.classList.remove(this.activeClassValue)
      t.setAttribute("aria-selected", "false")
    })
    this.panelTargets.forEach(p => p.classList.add(this.hiddenClassValue))

    // Activate selected
    tabEl.classList.add(this.activeClassValue)
    tabEl.setAttribute("aria-selected", "true")
    const panel = this.panelTargets.find(p => this.keyFor(p) === key)
    if (panel) panel.classList.remove(this.hiddenClassValue)

    // Hash sync
    if (this.rememberValue && pushHash) {
      const newHash = `#${key}`
      if (window.location.hash !== newHash) {
        history.pushState(null, "", newHash)
      }
    }
  }

  keyFor(el) {
    return el?.dataset?.key || null
  }
}
