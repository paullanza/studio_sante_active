import { Controller } from "@hotwired/stimulus"

// Edit-only controller for consultation rows:
// - swap to edit row
// - cancel back to read-only row
// - save edits (date, time, presence, identity fields, note)
// - delete row via modal
// - disassociate via modal confirm
// - info modal when already associated
export default class extends Controller {
  static values = {
    id: Number,
    editUrl: String,
    rowUrl: String,
    updateUrl: String,
    showBulk: Boolean
  }

  // Prefer the clicked link's href if present; fallback to data value
  async edit(event) {
    event.preventDefault()
    const href = event?.currentTarget?.getAttribute("href")
    const url  = this._urlWithShowBulk(href || this.editUrlValue)
    await this._replace(url)
  }

  async cancel(event) {
    event.preventDefault()
    const href = event?.currentTarget?.getAttribute("href")
    const url  = this._urlWithShowBulk(href || this.rowUrlValue)
    await this._replace(url)
  }

  async save(event) {
    event.preventDefault()
    const body = this._collectFormData()
    if (this.showBulkValue) body.append("show_bulk", "1")
    await this._replace(this.updateUrlValue, body, "PATCH")
  }

  // --- delete with confirmation modal ---
  confirmDelete(event) {
    event.preventDefault()
    const link = event.currentTarget
    const href = link.getAttribute("href")
    if (!href) return

    this._openModal({
      title: link.dataset.modalTitle,
      body: link.dataset.modalBody,
      primaryLabel: link.dataset.modalPrimaryLabel,
      secondaryLabel: link.dataset.modalSecondaryLabel,
      onConfirm: () => this._delete(href)
    })
  }

  confirmDisassociate(event) {
    event.preventDefault()
    const btn  = event.currentTarget
    const form = btn.closest("form")

    this._openModal({
      title: btn.dataset.modalTitle || "Retirer l’association",
      body: btn.dataset.modalBody || "Retirer l’association ?",
      primaryLabel: btn.dataset.modalPrimaryLabel || "Retirer",
      secondaryLabel: btn.dataset.modalSecondaryLabel || "Annuler",
      onConfirm: () => this._disassociateViaAjax(form)   // 👈 AJAX instead of form.submit()
    })
  }

  infoAlreadyAssociated(event) {
    event.preventDefault()
    const el = event.currentTarget

    this._openModal({
      title: el.dataset.modalTitle || "Association déjà présente",
      body: el.dataset.modalBody || "Cette consultation est déjà associée.",
      primaryLabel: el.dataset.modalPrimaryLabel || "OK",
      secondaryLabel: el.dataset.modalSecondaryLabel || "Fermer",
      onConfirm: null // close only
    })
  }

  // ----- private helpers -----
  _openModal({ title, body, primaryLabel, secondaryLabel, onConfirm }) {
    const modalEl = document.getElementById("app-modal")
    if (!modalEl) {
      // Fallback to window.confirm if no modal is present
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
    if (!(resp.status === 200 || resp.status === 422)) return

    const html = await resp.text()
    const tpl = document.createElement("template")
    tpl.innerHTML = html.trim()
    const rows = Array.from(tpl.content.children)

    const mainRow = this.element
    const noteRow =
      document.getElementById(`${mainRow.id}_note`) ||
      document.getElementById(`note_${mainRow.id}`)

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
      const noteRow =
        document.getElementById(`${mainRow.id}_note`) ||
        document.getElementById(`note_${mainRow.id}`)
      if (noteRow) noteRow.remove()
      mainRow.remove()
    }
  }

  async _disassociateViaAjax(form) {
    if (!form) return
    const action = form.getAttribute("action")
    const token  = document.querySelector('meta[name="csrf-token"]')?.content || ""

    const body = new FormData()
    body.append("_method", "patch")
    // preserve bulk UI if needed
    if (this.showBulkValue) body.append("show_bulk", "1")

    const resp = await fetch(action, {
      method: "POST",
      headers: {
        "Accept": "text/html",                // ask for HTML
        "X-Requested-With": "XMLHttpRequest", // hint server it's XHR
        "X-CSRF-Token": token
      },
      body
    })

    // Regardless of redirect or partial, refresh only this row
    if (resp.ok) {
      await this._replace(this.rowUrlValue)
    }
  }

  _urlWithShowBulk(url) {
    if (!this.showBulkValue) return url
    try {
      const u = new URL(url, window.location.origin)
      u.searchParams.set("show_bulk", "1")
      return u.toString()
    } catch {
      const sep = url.includes("?") ? "&" : "?"
      return `${url}${sep}show_bulk=1`
    }
  }

  _collectFormData() {
    const fd = new FormData()
    fd.append("_method", "patch")

    const row = this.element
    const getVal = (sel) => row.querySelector(sel)?.value || ""

    // Core editable fields
    fd.append("consultation[date]", getVal('input[name="consultation[date]"]'))
    fd.append("consultation[time]", getVal('input[name="consultation[time]"]'))

    const present = row.querySelector('input[name="consultation[present]"]')
    if (present) fd.append("consultation[present]", present.checked ? "1" : "0")

    fd.append("consultation[first_name]", getVal('input[name="consultation[first_name]"]'))
    fd.append("consultation[last_name]", getVal('input[name="consultation[last_name]"]'))
    fd.append("consultation[email]", getVal('input[name="consultation[email]"]'))
    fd.append("consultation[phone_number]", getVal('input[name="consultation[phone_number]"]'))

    const userSel = row.querySelector('select[name="consultation[user_id]"]')
    if (userSel) fd.append("consultation[user_id]", userSel.value)

    // Note textarea can be rendered as a sibling row
    const noteArea =
      document.querySelector(`#${row.id}_note textarea[name="consultation[note]"]`) ||
      document.querySelector(`#note_${row.id} textarea[name="consultation[note]"]`) ||
      (row.nextElementSibling?.matches?.(".note-row") ? row.nextElementSibling.querySelector('textarea[name="consultation[note]"]') : null)

    if (noteArea) fd.append("consultation[note]", noteArea.value)

    return fd
  }
}
