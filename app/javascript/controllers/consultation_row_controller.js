import { Controller } from "@hotwired/stimulus"

// Ultra-lean: swap row partials via fetch; delete via modal.
// No copy here — all text comes from data-* set by Rails helpers.
export default class extends Controller {
  static values = {
    id: Number,
    editUrl: String,
    rowUrl: String,
    updateUrl: String,
    showBulk: Boolean
  }

  // Load the edit form row
  async edit(event) {
    event.preventDefault()
    const url = this._urlWithShowBulk(this.editUrlValue || event?.currentTarget?.href)
    await this._replace(url)
  }

  // Restore the read-only row
  async cancel(event) {
    event.preventDefault()
    const url = this._urlWithShowBulk(this.rowUrlValue || event?.currentTarget?.href)
    await this._replace(url)
  }

  // Save changes and replace row
  async save(event) {
    event.preventDefault()
    const body = this._collectFormData()
    if (this.showBulkValue) body.append("show_bulk", "1")
    await this._replace(this.updateUrlValue, body, "PATCH")
  }

  // Open global modal and DELETE on confirm (no text literals here)
  confirmDelete(event) {
    event.preventDefault()
    const link = event.currentTarget
    const href = link.getAttribute("href")
    if (!href) return

    const { modalTitle, modalBody, modalPrimaryLabel, modalSecondaryLabel } = link.dataset

    const modalEl = document.getElementById("app-modal")
    if (modalEl) {
      modalEl.dispatchEvent(new CustomEvent("modal:open", {
        detail: {
          title: modalTitle,
          body: modalBody,
          primaryLabel: modalPrimaryLabel,
          secondaryLabel: modalSecondaryLabel,
          onConfirm: () => this._delete(href)
        }
      }))
    } else {
      // Fallback sans texte en dur: on utilise ce que la vue a fourni
      if (!modalBody || window.confirm(modalBody)) this._delete(href)
    }
  }

  // ----- private helpers -----
  async _replace(url, body = null, method = "GET") {
    const options = {
      method,
      headers: {
        "Accept": "text/html",
        "X-Requested-With": "XMLHttpRequest",
      },
    }
    if (body) {
      options.body = body
      options.headers["X-CSRF-Token"] =
        document.querySelector('meta[name="csrf-token"]')?.content || ""
    }

    const resp = await fetch(url, options)
    // Accept normal success AND 422 (validation error returns edit partial)
    if (!(resp.status === 200 || resp.status === 422)) return

    const html = await resp.text()
    const tpl = document.createElement("template")
    tpl.innerHTML = html.trim()
    const rows = Array.from(tpl.content.children)

    const mainRow = this.element
    const noteRow = document.getElementById(`${mainRow.id}_note`) || document.getElementById(`note_${mainRow.id}`)

    // Insert new main row then remove old
    if (rows[0]) {
      mainRow.insertAdjacentElement("afterend", rows[0])
      mainRow.remove()
    }

    // Replace note row if present
    if (noteRow) noteRow.remove()
    if (rows[1]) {
      const newMain = document.getElementById(rows[0].id) || rows[0]
      newMain.insertAdjacentElement("afterend", rows[1])
    }
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
    if (resp.ok) {
      const mainRow = this.element
      const noteRow = document.getElementById(`${mainRow.id}_note`) || document.getElementById(`note_${mainRow.id}`)
      if (noteRow) noteRow.remove()
      mainRow.remove()
    }
  }

  _urlWithShowBulk(url) {
    if (!this.showBulkValue) return url
    try {
      const u = new URL(url, window.location.origin)
      u.searchParams.set("show_bulk", "1")
      return u.toString()
    } catch {
      // Fallback if url is relative string without base
      const sep = url.includes("?") ? "&" : "?"
      return `${url}${sep}show_bulk=1`
    }
  }

  _collectFormData() {
    const fd = new FormData()
    fd.append("_method", "patch")

    const row = this.element
    const getVal = (sel) => row.querySelector(sel)?.value || ""

    fd.append("consultation[date]", getVal('input[name="consultation[date]"]'))
    fd.append("consultation[time]", getVal('input[name="consultation[time]"]'))

    const present = row.querySelector('input[name="consultation[present]"]')
    if (present) fd.append("consultation[present]", present.checked ? "1" : "0")

    const userSel = row.querySelector('select[name="consultation[user_id]"]')
    if (userSel) fd.append("consultation[user_id]", userSel.value)

    const noteArea = document.querySelector(`#${row.id}_note textarea[name="consultation[note]"]`)
    if (noteArea) fd.append("consultation[note]", noteArea.value)

    return fd
  }
}
