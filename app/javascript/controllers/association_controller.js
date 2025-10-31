import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    id: Number,
    editUrl: String,
    rowUrl: String,
    updateUrl: String,
    serviceSelectUrl: String,
    showBulk: Boolean,
    alreadyLinked: Boolean   // 👈 new: provided by data-association-already-linked-value
  }

  connect() {
    this._updateSaveDisabled()
  }

  edit(event) {
    if (event) event.preventDefault()
    this._fetchAndSwap(this._withShowBulk(this.editUrlValue))
  }

  cancel(event) {
    if (event) event.preventDefault()
    this._fetchAndSwap(this._withShowBulk(this.rowUrlValue))
  }

  loadServices(event) {
    const userId = this._userId()
    if (!userId) return
    const url = new URL(this.serviceSelectUrlValue, window.location.origin)
    url.searchParams.set("fliip_user_id", userId)
    const frame = this._serviceFrame()
    if (!frame) return
    fetch(url.toString(), { headers: { "X-Requested-With": "XMLHttpRequest" } })
      .then(r => r.text())
      .then(html => {
        frame.innerHTML = html
        this._updateSaveDisabled()
      })
      .catch(() => {})
  }

  async save(event) {
    if (event) event.preventDefault()

    // If this consultation is already linked, show info modal and stop here.
    if (this.hasAlreadyLinkedValue && this.alreadyLinkedValue) {
      const btn = event?.currentTarget
      this._openModal({
        title: btn?.dataset?.modalTitle || "Association déjà présente",
        body: btn?.dataset?.modalBody || "Cette consultation est déjà associée.",
        primaryLabel: btn?.dataset?.modalPrimaryLabel || "OK",
        secondaryLabel: btn?.dataset?.modalSecondaryLabel || "Fermer",
        onConfirm: null
      })
      return
    }

    const userId = this._userId()
    const serviceId = this._serviceId()
    if (!userId || !serviceId) return

    const body = new URLSearchParams()
    body.set("fliip_user_id", userId)
    body.set("fliip_service_id", serviceId)
    if (this.hasShowBulkValue && this.showBulkValue) body.set("show_bulk", "1")

    try {
      const r = await fetch(this.updateUrlValue, {
        method: "PATCH",
        headers: this._headers(),
        body
      })
      const html = await r.text()

      // If server rejected with 422 (uniqueness hit), refresh row then show info modal.
      if (r.status === 422) {
        this._replaceRow(html)
        const btn = event?.currentTarget
        this._openModal({
          title: btn?.dataset?.modalTitle || "Association déjà présente",
          body: btn?.dataset?.modalBody || "Cette consultation est déjà associée.",
          primaryLabel: btn?.dataset?.modalPrimaryLabel || "OK",
          secondaryLabel: btn?.dataset?.modalSecondaryLabel || "Fermer",
          onConfirm: null
        })
        return
      }

      // 200 or other OK → replace row with response HTML
      if (r.ok) {
        this._replaceRow(html)
      }
    } catch {
      // no-op; keep current UI
    }
  }

  _withShowBulk(url) {
    if (!(this.hasShowBulkValue && this.showBulkValue)) return url
    const u = new URL(url, window.location.origin)
    u.searchParams.set("show_bulk", "1")
    return u.toString()
  }

  _fetchAndSwap(url) {
    fetch(url, { headers: { "X-Requested-With": "XMLHttpRequest" } })
      .then(r => r.text())
      .then(html => this._replaceRow(html))
      .catch(() => {})
  }

  _replaceRow(html) {
    const temp = document.createElement("tbody")
    temp.innerHTML = html.trim()
    const newRow = temp.querySelector("tr")
    if (!newRow) return
    this.element.replaceWith(newRow)
  }

  _serviceFrame() {
    return document.getElementById(`service-select-frame-${this.idValue}`)
  }

  _userSelect() {
    return this.element.querySelector('select[name="fliip_user_id"]')
  }

  _serviceSelect() {
    return this.element.querySelector('select[name="fliip_service_id"]')
  }

  _userId() {
    const sel = this._userSelect()
    return sel ? (sel.value || "").trim() : ""
  }

  _serviceId() {
    const sel = this._serviceSelect()
    return sel ? (sel.value || "").trim() : ""
  }

  _updateSaveDisabled() {
    const btn = this.element.querySelector('[data-action~="association#save"]')
    if (!btn) return
    btn.disabled = !(this._userId() && this._serviceId())
  }

  _headers() {
    const token = document.querySelector('meta[name="csrf-token"]')?.content || ""
    return {
      "X-CSRF-Token": token,
      "X-Requested-With": "XMLHttpRequest",
      "Content-Type": "application/x-www-form-urlencoded;charset=UTF-8"
    }
  }

  _openModal({ title, body, primaryLabel, secondaryLabel, onConfirm }) {
    const modalEl = document.getElementById("app-modal")
    if (!modalEl) {
      if (!body || window.confirm(body)) onConfirm?.()
      return
    }
    modalEl.dispatchEvent(new CustomEvent("modal:open", {
      detail: {
        title: title || "",
        body: body || "",
        primaryLabel: primaryLabel || "Continuer",
        secondaryLabel: secondaryLabel || "Annuler",
        onConfirm
      }
    }))
  }
}
