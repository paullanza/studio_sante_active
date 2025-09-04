import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { id: Number, showBulk: Boolean }

  edit(event) {
    event.preventDefault()
    this._fetchReplace(this._url("edit"))
  }

  cancel(event) {
    event.preventDefault()
    this._fetchReplace(this._url("row"), { cache: "no-store" })
  }

  async save(event) {
    event.preventDefault()

    const main    = this.element
    const noteRow = this._adjacentNoteRow(main)

    const fd = new FormData()
    // date/time
    fd.append("session[date]", main.querySelector('input[name="session[date]"]')?.value || "")
    fd.append("session[time]", main.querySelector('input[name="session[time]"]')?.value || "")

    // present / half_hour
    if (main.querySelector('input[name="session[present]"]')?.checked) fd.append("session[present]", "1")
    if (main.querySelector('input[name="half_hour"]')?.checked)        fd.append("half_hour", "1")

    // admin: employee reassignment
    const userSelect = main.querySelector('select[name="session[user_id]"]')
    if (userSelect) fd.append("session[user_id]", userSelect.value)

    // note (in the adjacent note row, if present)
    fd.append("session[note]", noteRow?.querySelector('textarea[name="session[note]"]')?.value || "")

    const token = document.querySelector('meta[name="csrf-token"]')?.content
    const resp  = await fetch(this._updateUrl(), {
      method: "PATCH",
      headers: { "Accept": "text/html", "X-CSRF-Token": token || "" },
      body: fd
    })

    const html = await resp.text()
    this._replacePair(html)
  }

  // --- helpers ---

  _url(action) {
    const base = `/sessions/${this.idValue}/${action}`
    return this.showBulkValue ? `${base}?show_bulk=1` : base
  }

  _updateUrl() {
    const base = `/sessions/${this.idValue}`
    return this.showBulkValue ? `${base}?show_bulk=1` : base
  }

  _fetchReplace(url, opts = {}) {
    fetch(url, { headers: { "Accept": "text/html" }, ...opts })
      .then(r => r.text())
      .then(html => this._replacePair(html))
  }

  // Replace the main <tr> and keep the adjacent note row in sync
  _replacePair(html) {
    const frag = document.createElement("tbody")
    frag.innerHTML = html.trim()

    // main row from server (prefer the one with our controller)
    const newMain = frag.querySelector('tr[data-controller~="session-row"]') || frag.querySelector("tr")
    if (!newMain) return

    const currentMain = this.element
    const existingNote = this._adjacentNoteRow(currentMain)
    const newNote      = frag.querySelector("tr.note-row")

    // swap main
    currentMain.replaceWith(newMain)

    // sync note directly under the new main
    if (newNote && existingNote) {
      existingNote.replaceWith(newNote)
    } else if (newNote && !existingNote) {
      newMain.insertAdjacentElement("afterend", newNote)
    } else if (!newNote && existingNote) {
      existingNote.remove()
    }
  }

  // Finds the note row that belongs to this main row (next sibling with .note-row)
  _adjacentNoteRow(row = this.element) {
    const sib = row.nextElementSibling
    return (sib && sib.classList.contains("note-row")) ? sib : null
  }
}
