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
    this.#clearError()
    this.#setLoading(true)
    this.#disableServiceSelect()
    this.#renderTable([])

    try {
      const services = await this.#fetchServices(userId)
      this.#populateServiceSelect(services)
      this.#renderTable(services)
    } catch (e) {
      this.#showError("Unable to load services. Please try again.")
    } finally {
      this.#setLoading(false)
    }
  }

  // ---------- Data ----------

  async #fetchServices(userId) {
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
    const opts = []
    opts.push(`<option value="">Select a service</option>`)

    services.forEach((svc) => {
      const label = `${this.#escape(svc.name)} (ID: ${svc.id})`
      const disabled = svc.selectable ? "" : " disabled"
      opts.push(`<option value="${svc.id}"${disabled}>${label}</option>`)
    })

    this.serviceSelectTarget.innerHTML = opts.join("")
    this.serviceSelectTarget.disabled = services.length === 0
  }

  #renderTable(services) {
    this.servicesTbodyTarget.innerHTML = ""

    if (!services || services.length === 0) {
      this.servicesTbodyTarget.appendChild(
        this.#makeRow({
          cells: [
            {
              text: "Select a client to view services.",
              attrs: { colspan: 6, class: "text-muted" },
            },
          ],
        })
      )
      return
    }

    services.forEach((svc) => {
      const paidUsed = this.#fmtNumber(svc.paid_used)
      const paidTotal = this.#fmtTotal(svc.paid_total)
      const freeUsed = this.#fmtNumber(svc.free_used)
      const freeTotal = this.#fmtTotal(svc.free_total)

      const isGrey = svc.status === "I" || svc.status === "C"
      const rowClass = isGrey ? "text-muted table-secondary" : null

      this.servicesTbodyTarget.appendChild(
        this.#makeRow({
          rowClass,
          cells: [
            { text: svc.name || "—" },
            { text: this.#fmtDate(svc.start_date) },
            { text: this.#fmtDate(svc.expire_date) },
            { text: svc.status_label || "—" },
            { text: `${paidUsed}/${paidTotal}` },
            { text: `${freeUsed}/${freeTotal}` },
          ],
        })
      )
    })
  }

  // ---------- UI helpers ----------

  #setLoading(isLoading) {
    if (!this.hasStatusTarget) return
    this.statusTarget.hidden = !isLoading
    this.statusTarget.textContent = isLoading ? "Loading services…" : ""
  }

  #disableServiceSelect() {
    this.serviceSelectTarget.innerHTML =
      `<option value="">Select a client first</option>`
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

  // ---------- Tiny DOM/format utils ----------

  #makeRow({ cells, rowClass = null }) {
    const tr = document.createElement("tr")
    if (rowClass) tr.setAttribute("class", rowClass)

    cells.forEach((c) => {
      const td = document.createElement("td")
      if (c.attrs) {
        Object.entries(c.attrs).forEach(([k, v]) => td.setAttribute(k, v))
      }
      td.textContent = c.text ?? "—"
      tr.appendChild(td)
    })
    return tr
  }

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

  #fmtTotal(t) {
    return t == null ? "—" : String(t)
  }

  #escape(s) {
    return (s || "").replace(/[&<>"']/g, (ch) => (
      { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[ch]
    ))
  }
}
