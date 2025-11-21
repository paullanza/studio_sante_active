import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "userId",
    "submit",
    "present",
    "halfHour",
  ]

  connect() {
    this._onFrameLoad = this._onFrameLoad.bind(this)
    document.addEventListener("turbo:frame-load", this._onFrameLoad)
    this._onServiceChange = () => this.recheck()
    this._updateSubmitDisabled()
  }

  disconnect() {
    document.removeEventListener("turbo:frame-load", this._onFrameLoad)
    const sel = this._serviceSelect()
    if (sel) sel.removeEventListener("change", this._onServiceChange)
  }

  maybeConfirm(event) {
    if (this._isDisabled()) {
      event.preventDefault()
      return
    }

    const dateStatus = this._dateWindowStatus()

    if (dateStatus) {
      event.preventDefault()

      const ds = this.hasSubmitTarget ? this.submitTarget.dataset : {}
      const isBefore = dateStatus === "before"

      const title = isBefore
        ? (ds.modalBeforeStartTitle || "Confirmer la séance")
        : (ds.modalAfterEndTitle || "Confirmer la séance")

      const body = isBefore
        ? (ds.modalBeforeStartBody || "")
        : (ds.modalAfterEndBody || "")

      const detail = {
        title: title,
        body: body,
        primaryLabel: ds.modalPrimaryLabel || "Continuer",
        secondaryLabel: ds.modalSecondaryLabel || "Annuler",
        onConfirm: () => this.element.requestSubmit()
      }

      const modalEl = document.getElementById("app-modal")
      if (modalEl) {
        modalEl.dispatchEvent(new CustomEvent("modal:open", { detail }))
      } else {
        const fallback = detail.body || detail.title
        if (window.confirm(fallback)) this.element.requestSubmit()
      }

      return
    }

    if (this._isPresent()) return

    event.preventDefault()

    const isFree = this._willCountAsFree()
    const ds = this.hasSubmitTarget ? this.submitTarget.dataset : {}

    const detail = {
      title: isFree ? (ds.modalFreeTitle || "Confirmer") : (ds.modalPaidTitle || "Confirmer"),
      body:  isFree ? (ds.modalFreeBody  || "")          : (ds.modalPaidBody  || ""),
      primaryLabel: ds.modalPrimaryLabel || "Continuer",
      secondaryLabel: ds.modalSecondaryLabel || "Annuler",
      onConfirm: () => this.element.requestSubmit()
    }

    const modalEl = document.getElementById("app-modal")
    if (modalEl) {
      modalEl.dispatchEvent(new CustomEvent("modal:open", { detail }))
    } else {
      const fallback = detail.body || detail.title
      if (window.confirm(fallback)) this.element.requestSubmit()
    }
  }

  recheck() {
    this._updateSubmitDisabled()
  }

  _onFrameLoad(e) {
    if (e.target.id !== "service_select") return
    const sel = this._serviceSelect()
    if (sel) {
      sel.removeEventListener("change", this._onServiceChange)
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

  _serviceSelect() {
    return (
      this.element.querySelector('select[name="session[fliip_service_id]"]') ||
      document.getElementById("service_select")?.querySelector('select[name="session[fliip_service_id]"]') ||
      null
    )
  }

  _serviceId() {
    const sel = this._serviceSelect()
    return sel ? (sel.value || "").trim() : ""
  }

  _isDisabled() {
    const sel = this._serviceSelect()
    if (!this._userId() || !sel) return true

    const value = (sel.value || "").trim()
    if (!value) return true

    const opt = sel.selectedOptions[0]
    if (opt && opt.disabled) return true

    return false
  }

  _updateSubmitDisabled() {
    if (!this.hasSubmitTarget) return
    this.submitTarget.disabled = this._isDisabled()
  }

  _willCountAsFree() {
    const sel = this._serviceSelect()
    if (!sel || !sel.selectedOptions.length) return false

    const opt = sel.selectedOptions[0]
    const hasDef        = (opt.dataset.hasDef === "true")
    const freeRemaining = parseFloat(opt.dataset.freeRemaining || "0")
    const dur           = this._durationHours()

    return hasDef && freeRemaining >= dur
  }

  _sessionDate() {
    const dateInput = this.element.querySelector('input[name="session[date]"]')
    const timeInput = this.element.querySelector('input[name="session[time]"]')

    if (!dateInput || !timeInput) return null

    const d = (dateInput.value || "").trim()
    const t = (timeInput.value || "").trim()
    if (!d || !t) return null

    const iso = `${d}T${t}:00`
    const dt = new Date(iso)
    return isNaN(dt.getTime()) ? null : dt
  }

  _serviceDates() {
    const sel = this._serviceSelect()
    if (!sel || !sel.selectedOptions.length) return { start: null, end: null }

    const opt = sel.selectedOptions[0]
    const startStr  = opt.dataset.startDate || ""
    const expireStr = opt.dataset.expireDate || ""

    const start = startStr ? new Date(`${startStr}T00:00:00`) : null
    const end   = expireStr ? new Date(`${expireStr}T23:59:59`) : null

    return {
      start: isNaN(start?.getTime()) ? null : start,
      end:   isNaN(end?.getTime())   ? null : end,
    }
  }

  _dateWindowStatus() {
    const sessionDate = this._sessionDate()
    if (!sessionDate) return null

    const { start, end } = this._serviceDates()

    if (start && sessionDate < start) return "before"
    if (end && sessionDate > end) return "after"
    return null
  }
}
