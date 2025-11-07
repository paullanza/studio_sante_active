import { Controller } from "@hotwired/stimulus"

// Drives the "associate consultation → client + service" row.
// Client via text input + autocomplete; service optional ("no purchase").
export default class extends Controller {
  static values = {
    id: Number,
    editUrl: String,
    rowUrl: String,
    updateUrl: String,
    serviceSelectUrl: String,
    suggestUrl: { type: String, default: "/fliip_users/suggest" },
    suggestionsFrameId: String,
    serviceFrameId: String,
    showBulk: Boolean,
    alreadyLinked: Boolean
  }

  static targets = ["nameInput", "hiddenClientId"]

  connect() {
    this._debounceTimer = null
    this._lastQuery = ""
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

  // --- Autocomplete ---
  onNameInput() {
    const q = (this.nameInputTarget.value || "").trim()
    if (q === this._lastQuery) return
    this._lastQuery = q

    clearTimeout(this._debounceTimer)
    if (q.length < 2) {
      this._clearSuggestions()
      return
    }

    this._debounceTimer = setTimeout(() => {
      const url = new URL(this.suggestUrlValue || "/fliip_users/suggest", window.location.origin)
      url.searchParams.set("query", q)
      this._fetchSuggestions(url.toString())
    }, 250)
  }

  onNameFocus() {
    const q = (this.nameInputTarget.value || "").trim()
    if (q.length >= 2 && !this._suggestionsHasContent()) {
      const url = new URL(this.suggestUrlValue || "/fliip_users/suggest", window.location.origin)
      url.searchParams.set("query", q)
      this._fetchSuggestions(url.toString())
    }
  }

  onNameBlur() {
    setTimeout(() => this._clearSuggestions(), 150)
  }

  pickClient(event) {
    const el = event.currentTarget
    const id = (el?.dataset?.id || "").trim()
    const name = (el?.dataset?.name || "").trim()
    if (!id) return

    this.hiddenClientIdTarget.value = id
    if (name) this.nameInputTarget.value = name
    this._clearSuggestions()
    this.loadServices()
  }

  // --- Services ---
  loadServices() {
    const userId = this._clientId()
    if (!userId) {
      this._replaceServiceFrame("")
      this._updateSaveDisabled()
      return
    }

    const url = new URL(this.serviceSelectUrlValue, window.location.origin)
    url.searchParams.set("fliip_user_id", userId)

    fetch(url.toString(), { headers: { "X-Requested-With": "XMLHttpRequest" } })
      .then(r => r.text())
      .then(html => {
        this._replaceServiceFrame(html)
        this._updateSaveDisabled()
      })
      .catch(() => {})
  }

  // --- Save ---
  async save(event) {
    if (event) event.preventDefault()

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

    const userId = this._clientId()
    const serviceId = this._serviceId()
    if (!userId) return

    const body = new URLSearchParams()
    body.set("fliip_user_id", userId)
    if (serviceId) body.set("fliip_service_id", serviceId)
    if (this.hasShowBulkValue && this.showBulkValue) body.set("show_bulk", "1")

    try {
      const r = await fetch(this.updateUrlValue, {
        method: "PATCH",
        headers: this._headers(),
        body
      })
      const html = await r.text()

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

      if (r.ok) {
        this._replaceRow(html)
      }
    } catch {
      // no-op
    }
  }

  // --- helpers ---
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

  _serviceFrameEl() {
    const id = this.serviceFrameIdValue || `service-select-frame-${this.idValue}`
    return document.getElementById(id)
  }

  _replaceServiceFrame(html) {
    const frame = this._serviceFrameEl()
    if (!frame) return
    frame.innerHTML = html
  }

  _clientId() {
    return this.hasHiddenClientIdTarget ? (this.hiddenClientIdTarget.value || "").trim() : ""
  }

  _serviceId() {
    const sel = this.element.querySelector('select[name="fliip_service_id"]')
    return sel ? (sel.value || "").trim() : ""
  }

  _updateSaveDisabled() {
    const btn = this.element.querySelector('[data-action~="association#save"]')
    if (!btn) return
    // Enable as soon as a client is selected; service is optional.
    btn.disabled = !this._clientId()
  }

  _headers() {
    const token = document.querySelector('meta[name="csrf-token"]')?.content || ""
    return {
      "X-CSRF-Token": token,
      "X-Requested-With": "XMLHttpRequest",
      "Content-Type": "application/x-www-form-urlencoded;charset=UTF-8"
    }
  }

  _fetchSuggestions(url) {
    fetch(url, { headers: { "X-Requested-With": "XMLHttpRequest" } })
      .then(r => r.text())
      .then(html => {
        const frame = this._suggestionsFrame()
        if (!frame) return
        frame.innerHTML = html
      })
      .catch(() => {})
  }

  _clearSuggestions() {
    const frame = this._suggestionsFrame()
    if (frame) frame.innerHTML = ""
  }

  _suggestionsHasContent() {
    const frame = this._suggestionsFrame()
    return frame ? frame.innerHTML.trim().length > 0 : false
  }

  _suggestionsFrame() {
    const id = this.suggestionsFrameIdValue || `client-suggestions-${this.idValue}`
    return document.getElementById(id)
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
