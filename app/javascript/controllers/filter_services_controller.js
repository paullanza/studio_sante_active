import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "userSelect",
    "serviceSelect",
    "servicesTbody",
    "status",
    "error",
    "emptyRow",
  ]

  connect() {
    this.cache = new Map()
    const userId = this.userSelectTarget?.value
    if (userId) this.onUserChange()
  }

  async onUserChange() {
    const userId = this.userSelectTarget.value
    if (!userId) {
      this.#disableServiceSelect()
      this.#renderPlaceholder("Select a client to view services.")
      return
    }

    this.#clearError()
    this.#setLoading(true)
    this.#disableServiceSelect()
    this.#renderPlaceholder("Loading…")

    try {
      const services = await this.#fetchServicesJSON(userId)
      this.#populateServiceSelect(services)
      this.#renderServicesRows(services)
    } catch (_e) {
      this.#showError("Unable to load services. Please try again.")
      this.#renderPlaceholder("—")
    } finally {
      this.#setLoading(false)
    }
  }

  // ---------- Data ----------
  async #fetchServicesJSON(userId) {
    if (this.cache.has(userId)) return this.cache.get(userId)

    const url = `/sessions/services_for_user?fliip_user_id=${encodeURIComponent(userId)}`
    const res = await fetch(url, { headers: { Accept: "application/json" } })
    if (!res.ok) throw new Error(`HTTP ${res.status}`)

    const json = await res.json()
    this.cache.set(userId, json)
    return json
  }

  // ---------- Rendering ----------
  #populateServiceSelect(services) {
    const opts = ['<option value="">Select a service</option>']

    services.forEach((svc) => {
      const label = `${this.#escape(svc.service_name || "Service")} (ID: ${svc.id})`
      const disabled = svc.selectable ? "" : " disabled"
      opts.push(`<option value="${svc.id}"${disabled}>${label}</option>`)
    })

    this.serviceSelectTarget.innerHTML = opts.join("")
    this.serviceSelectTarget.disabled = services.length === 0
  }

  #renderServicesRows(services) {
    const COLS = 10
    this.servicesTbodyTarget.innerHTML = ""

    if (!services || services.length === 0) {
      this.#renderPlaceholder("No services for this client.", COLS)
      return
    }

    const rows = services.map((svc) => {
      const isGrey = svc.status === "I" || svc.status === "C"
      const rowClass = isGrey ? "text-muted table-secondary" : ""

      // Time progress (from backend or default)
      const timePct = this.#num(svc.time_progress_percent)
      const timeLbl = this.#escape(svc.time_range_label || "—")

      // Prefer flat keys; fallback to nested usage_stats to be resilient
      const us = svc.usage_stats || {}
      const paidObj = us.paid || {}
      const freeObj = us.free || {}

      const paidUsed  = this.#num1( svc.paid_used_total ?? svc.paid_used ?? paidObj.used_sessions )
      const paidIncl  = this.#firstPresent( svc.paid_included, svc.paid_total, paidObj.included )
      const paidBonus = this.#num1( svc.paid_bonus_total ?? paidObj.bonus )
      const paidAllow = this.#num1( svc.paid_allowed_total ?? paidObj.allowed_total ?? ((this.#present(paidIncl) ? Number(paidIncl) : 0) + (paidBonus || 0)) )
      const paidPct   = this.#num( svc.paid_usage_percent ?? svc.paid_progress_percent ?? (paidAllow > 0 ? (paidUsed / paidAllow) * 100 : 0) )

      const freeUsed  = this.#num1( svc.free_used_total ?? svc.free_used ?? freeObj.used_sessions )
      const freeIncl  = this.#firstPresent( svc.free_included, svc.free_total, freeObj.included )

      // Labels
      const paidUsedLabel = this.#fmtNumber(paidUsed)
      const paidInclLabel = this.#present(paidIncl) ? this.#escape(String(paidIncl)) : "—"
      const bonusLabel = paidBonus && paidBonus !== 0 ? ` <span class="text-muted">( +${this.#fmtNumber(paidBonus)} bonus )</span>` : ""

      const hasFree = this.#present(freeUsed) || this.#present(freeIncl)
      const freeUsedLabel = this.#present(freeUsed) ? this.#fmtNumber(freeUsed) : "—"
      const freeInclLabel = this.#present(freeIncl) ? this.#escape(String(freeIncl)) : "—"
      const freeBracket = hasFree ? `<span class="ms-2 text-muted">[${freeUsedLabel}/${freeInclLabel} absences]</span>` : ""

      return `
        <tr class="${rowClass}">
          <td>${this.#escape(svc.remote_purchase_id ?? "—")}</td>
          <td>${this.#escape(svc.status_label || "—")}</td>
          <td>${this.#fmtDate(svc.start_date)}</td>
          <td>${this.#fmtDate(svc.expire_date)}</td>
          <td>${this.#fmtDate(svc.purchase_date)}</td>
          <td>${this.#fmtDate(svc.stop_date)}</td>
          <td>${this.#fmtDate(svc.cancel_date)}</td>
          <td>${this.#escape(svc.service_name || "—")}</td>
          <td>${this.#escape(svc.duration == null ? "—" : String(svc.duration))}</td>
          <td style="min-width:240px;">
            <div class="mb-2">
              <div class="d-flex justify-content-between small">
                <span>Time</span>
                <span>${timeLbl} • ${timePct}%</span>
              </div>
              <div class="progress" role="progressbar" aria-label="Time progress"
                   aria-valuemin="0" aria-valuemax="100" aria-valuenow="${timePct}">
                <div class="progress-bar bg-info" style="width:${timePct}%"></div>
              </div>
            </div>

            <div>
              <div class="d-flex justify-content-between small">
                <span>Sessions</span>
                <span>
                  ${paidUsedLabel}/${paidInclLabel} sessions
                  ${bonusLabel} • ${paidPct}%
                  ${freeBracket}
                </span>
              </div>
              <div class="progress" role="progressbar" aria-label="Paid sessions usage"
                   aria-valuemin="0" aria-valuemax="100" aria-valuenow="${paidPct}">
                <div class="progress-bar bg-success" style="width:${paidPct}%"></div>
              </div>
            </div>
          </td>
        </tr>
      `
    })

    this.servicesTbodyTarget.innerHTML = rows.join("")
  }

  #renderPlaceholder(text, colspan = 10) {
    this.servicesTbodyTarget.innerHTML = `
      <tr>
        <td class="text-muted" colspan="${colspan}">${this.#escape(text)}</td>
      </tr>
    `
  }

  // ---------- UI helpers ----------
  #setLoading(isLoading) {
    if (!this.hasStatusTarget) return
    this.statusTarget.hidden = !isLoading
    this.statusTarget.textContent = isLoading ? "Loading services…" : ""
  }

  #disableServiceSelect() {
    this.serviceSelectTarget.innerHTML = `<option value="">Select a client first</option>`
    this.serviceSelectTarget.disabled = true
  }

  #showError(msg) {
    if (!this.hasErrorTarget) return
    this.errorTarget.hidden = false
    this.errorTarget.textContent = msg
  }

  #clearError() {
    if (!this.hasErrorTarget) return
    this.errorTarget.hidden = true
    this.errorTarget.textContent = ""
  }

  // ---------- tiny utils ----------
  #fmtDate(value) {
    if (!value) return "—"
    const d = new Date(value)
    if (Number.isNaN(d.getTime())) return "—"
    const dd = String(d.getDate()).padStart(2, "0")
    const mm = String(d.getMonth() + 1).padStart(2, "0")
    const yyyy = d.getFullYear()
    return `${dd}/${mm}/${yyyy}`
  }

  #fmtNumber(n) {
    const num = Number(n)
    return Number.isFinite(num) ? num.toFixed(1) : "0.0"
  }

  #num(n) {
    const v = Number(n)
    if (!Number.isFinite(v)) return 0
    if (v < 0) return 0
    if (v > 100) return 100
    return Math.round(v)
  }

  #num1(n) {
    const v = Number(n)
    return Number.isFinite(v) ? v : 0
  }

  #present(v) {
    return !(v === null || v === undefined || v === "")
  }

  #firstPresent(...vals) {
    for (const v of vals) {
      if (this.#present(v)) return v
    }
    return null
  }

  #escape(s) {
    return (s ?? "").toString().replace(/[&<>"']/g, (ch) => (
      { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[ch]
    ))
  }
}
