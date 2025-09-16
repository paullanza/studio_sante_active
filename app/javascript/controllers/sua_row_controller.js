import { Controller } from "@hotwired/stimulus"

// Row-swapping for Service Usage Adjustments
export default class extends Controller {
  static values = {
    id: Number,
    editUrl: String,
    updateUrl: String,
    indexUrl: String
  }

  async edit(event) {
    event.preventDefault()
    await this._replace(this.editUrlValue || event.currentTarget.href)
  }

  async cancel(event) {
    event.preventDefault()
    // Fallback: reload the service page and pick the row by id
    await this._reloadRowFromIndex()
  }

  async save(event) {
    event.preventDefault()
    const body = this._collectFormData()
    await this._replace(this.updateUrlValue, body, "PATCH", /*accept422*/ true)
  }

  confirmDelete(event) {
    event.preventDefault()
    const link = event.currentTarget
    const href = link.getAttribute("href")
    if (!href) return

    const { modalTitle, modalBody, modalPrimaryLabel, modalSecondaryLabel } = link.dataset
    const modalEl = document.getElementById("app-modal")

    const doDelete = () => this._delete(href)

    if (modalEl) {
      modalEl.dispatchEvent(new CustomEvent("modal:open", {
        detail: {
          title: modalTitle,
          body: modalBody,
          primaryLabel: modalPrimaryLabel,
          secondaryLabel: modalSecondaryLabel,
          onConfirm: doDelete
        }
      }))
    } else {
      if (!modalBody || window.confirm(modalBody)) doDelete()
    }
  }

  // ----- helpers -----
  async _replace(url, body = null, method = "GET", accept422 = false) {
    const headers = { "Accept": "text/html", "X-Requested-With": "XMLHttpRequest" }
    if (body) headers["X-CSRF-Token"] = document.querySelector('meta[name="csrf-token"]')?.content || ""

    const resp = await fetch(url, { method, headers, body })
    if (!(resp.status === 200 || (accept422 && resp.status === 422))) return

    const html = await resp.text()
    const tpl = document.createElement("template")
    tpl.innerHTML = html.trim()

    // Prefer finding a TR with our id; else take first child
    const newRow = tpl.content.querySelector(`#${this.element.id}`) || tpl.content.querySelector("tr")
    if (!newRow) return

    this.element.insertAdjacentElement("afterend", newRow)
    this.element.remove()
  }

  async _reloadRowFromIndex() {
    const resp = await fetch(this.indexUrlValue, {
      headers: { "Accept": "text/html", "X-Requested-With": "XMLHttpRequest" }
    })
    if (!resp.ok) return
    const html = await resp.text()
    const tpl = document.createElement("template")
    tpl.innerHTML = html.trim()
    const selector = `#${this.element.id}`
    const newRow = tpl.content.querySelector(selector)
    if (newRow) {
      this.element.insertAdjacentElement("afterend", newRow)
      this.element.remove()
    }
  }

  _collectFormData() {
    const fd = new FormData()
    fd.append("_method", "patch")
    const row = this.element

    const get = (name) => row.querySelector(`[name="${name}"]`)?.value ?? ""
    fd.append("service_usage_adjustment[paid_used_delta]", get("service_usage_adjustment[paid_used_delta]"))
    fd.append("service_usage_adjustment[free_used_delta]", get("service_usage_adjustment[free_used_delta]"))
    fd.append("service_usage_adjustment[bonus_sessions]", get("service_usage_adjustment[bonus_sessions]"))

    const userSel = row.querySelector('select[name="service_usage_adjustment[user_id]"]')
    if (userSel) fd.append("service_usage_adjustment[user_id]", userSel.value)

    return fd
  }

  async _delete(url) {
    const resp = await fetch(url, {
      method: "DELETE",
      headers: {
        "Accept": "application/json",
        "X-Requested-With": "XMLHttpRequest",
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content || ""
      }
    })
    if (resp.ok) this.element.remove()
  }
}
import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="sua-row"
export default class extends Controller {
  connect() {
  }
}
