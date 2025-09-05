import { Controller } from "@hotwired/stimulus"

// Try to use Bootstrap Modal if available; otherwise null
const getBSModal = (el) => {
  try { return window.bootstrap?.Modal?.getOrCreateInstance(el) || null } catch { return null }
}

export default class extends Controller {
  static targets = [
    "userId",     // hidden input: session[fliip_user_id]
    "submit",     // the Create Session button
    "present",    // checkbox
    "halfHour",   // checkbox
    // Optional modal parts (if you have a Bootstrap modal on the page)
    "modal", "modalTitle", "modalBody", "modalConfirm"
  ]

  connect() {
    this._onFrameLoad = this._onFrameLoad.bind(this)
    document.addEventListener("turbo:frame-load", this._onFrameLoad)

    // For vanilla modal fallback:
    this._onDismissClick = (e) => {
      if (e.target.closest('[data-bs-dismiss="modal"]')) this._hideModal()
    }
    this._vanillaBound = false

    // change handler for service select (set when frame loads)
    this._onServiceChange = () => this.recheck()

    this._updateSubmitDisabled()
  }

  disconnect() {
    document.removeEventListener("turbo:frame-load", this._onFrameLoad)
    // Clean up service <select> listener if present
    const sel = this._serviceSelect()
    if (sel) sel.removeEventListener("change", this._onServiceChange)
    // Cleanup modal fallback listeners/backdrop if used
    if (this.hasModalTarget && this._vanillaBound) {
      this.modalTarget.removeEventListener("click", this._onDismissClick)
    }
    this._removeBackdrop()
  }

  // Button handler
  maybeConfirm(event) {
    if (this._isDisabled()) { event.preventDefault(); return }

    // Only confirm for Absent
    if (this._isPresent()) return

    event.preventDefault()

    const msg = this._confirmMessage()

    if (this.hasModalTarget && this.hasModalTitleTarget && this.hasModalBodyTarget && this.hasModalConfirmTarget) {
      this.modalTitleTarget.textContent = msg.title
      this.modalBodyTarget.textContent  = msg.body

      const proceed = () => {
        this.modalConfirmTarget.removeEventListener("click", proceed)
        this._hideModal()
        this.element.requestSubmit() // real submit
      }
      this.modalConfirmTarget.addEventListener("click", proceed)

      this._showModal()
    } else {
      // Last-ditch fallback
      if (window.confirm(msg.fallback)) this.element.requestSubmit()
    }
  }

  // Triggered by inputs with data-action="change->session-form#recheck"
  recheck() { this._updateSubmitDisabled() }

  // ---- private helpers ----

  _onFrameLoad(e) {
    if (e.target.id !== "service_select") return
    // Wire up the select's change event whenever the frame renders
    const sel = this._serviceSelect()
    if (sel) {
      sel.removeEventListener("change", this._onServiceChange) // avoid dupes
      sel.addEventListener("change", this._onServiceChange)
    }
    this._updateSubmitDisabled()
  }

  _isPresent() {
    return this.hasPresentTarget ? !!this.presentTarget.checked : false
  }

  _durationHours() {
    return (this.hasHalfHourTarget && this.halfHourTarget.checked) ? 0.5 : 1.0
  }

  _userId() {
    if (this.hasUserIdTarget) return (this.userIdTarget.value || "").trim()
    return (this.element.querySelector('input[name="session[fliip_user_id]"]')?.value || "").trim()
  }

  // Select may live inside the #service_select Turbo frame
  _serviceSelect() {
    return (
      this.element.querySelector('select[name="session[fliip_service_id]"]')
      || document.getElementById("service_select")?.querySelector('select[name="session[fliip_service_id]"]')
      || null
    )
  }

  _serviceId() {
    const sel = this._serviceSelect()
    return sel ? (sel.value || "").trim() : ""
  }

  _isDisabled() {
    return !(this._userId() && this._serviceId())
  }

  _updateSubmitDisabled() {
    if (!this.hasSubmitTarget) return
    this.submitTarget.disabled = this._isDisabled()
  }

  // FREE vs PAID for an absent session (client-side heuristic from <option data-*>)
  _willCountAsFree() {
    const sel = this._serviceSelect()
    if (!sel || !sel.selectedOptions.length) return false

    const opt = sel.selectedOptions[0]
    const hasDef        = (opt.dataset.hasDef === "true")
    const freeRemaining = parseFloat(opt.dataset.freeRemaining || "0")
    const dur           = this._durationHours()

    return hasDef && freeRemaining >= dur
  }

  _confirmMessage() {
    const isFree = this._willCountAsFree()
    if (isFree) {
      return {
        title: "Confirm Absent (FREE session)",
        body:  "This will create an ABSENT session that will count as FREE (free balance covers the duration). Do you want to continue?",
        fallback: "This will create an ABSENT session that counts as FREE. Continue?"
      }
    } else {
      return {
        title: "Confirm Absent (PAID session)",
        body:  "This will create an ABSENT session that will count as PAID (insufficient free balance). Do you want to continue?",
        fallback: "This will create an ABSENT session that counts as PAID. Continue?"
      }
    }
  }

  // ----- Modal helpers (Bootstrap or vanilla) -----

  _showModal() {
    const el = this.modalTarget
    const bs = getBSModal(el)
    if (bs) { bs.show(); return }

    // Vanilla fallback: emulate Bootstrap modal behavior
    this._addBackdrop()
    el.classList.add("show")
    el.style.display = "block"
    el.removeAttribute("aria-hidden")
    el.setAttribute("aria-modal", "true")
    el.setAttribute("role", "dialog")

    if (!this._vanillaBound) {
      this.modalTarget.addEventListener("click", this._onDismissClick)
      document.addEventListener("keydown", this._escClose)
      this._vanillaBound = true
    }
  }

  _hideModal() {
    const el = this.modalTarget
    const bs = getBSModal(el)
    if (bs) { bs.hide(); return }

    el.classList.remove("show")
    el.style.display = "none"
    el.setAttribute("aria-hidden", "true")
    el.removeAttribute("aria-modal")
    el.removeAttribute("role")
    this._removeBackdrop()
  }

  _addBackdrop() {
    if (this._backdrop) return
    const bd = document.createElement("div")
    bd.className = "modal-backdrop fade show"
    document.body.appendChild(bd)
    this._backdrop = bd
  }

  _removeBackdrop() {
    if (this._backdrop) {
      this._backdrop.remove()
      this._backdrop = null
    }
  }
}
