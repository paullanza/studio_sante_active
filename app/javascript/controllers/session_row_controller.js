import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { id: Number }

  connect() {
    // Optionally store a reference to the sibling note row id
    this.noteId = `session_${this.idValue}_note`
  }

  edit(event) {
    event.preventDefault()
    this._fetchReplace(this._url(`edit`))
    // Hide the note row while editing (if present)
    const note = document.getElementById(this.noteId)
    if (note) note.classList.add("d-none")
  }

  cancel(event) {
    event.preventDefault()
    this._fetchReplace(this._url(`row`), { cache: "no-store" })
  }

  submit(event) {
    event.preventDefault()
    const form = event.target
    const fd = new FormData(form)

    fetch(form.action, {
      method: "PATCH",
      headers: { "Accept": "text/html" },
      body: fd
    }).then(async (resp) => {
      const html = await resp.text()
      this._replacePair(html)
    })
  }

  // --- helpers ---

  _url(action) { return `/sessions/${this.idValue}/${action}` }

  _fetchReplace(url, opts = {}) {
    fetch(url, { headers: { "Accept": "text/html" }, ...opts })
      .then(r => r.text())
      .then(html => this._replacePair(html))
  }

  // Replace the main <tr> and keep the note row in sync with server response
  _replacePair(html) {
    const frag = document.createElement("tbody")
    frag.innerHTML = html.trim()

    // first <tr> is the main row
    const newMain = frag.querySelector("tr")
    if (!newMain) return

    const currentMain = this.element
    // if server also returned a note row, capture it
    const newNote = frag.querySelector(`#${this.noteId}`)

    // Replace main row
    currentMain.replaceWith(newMain)

    // Update note row
    const existingNote = document.getElementById(this.noteId)
    if (newNote && existingNote) {
      existingNote.replaceWith(newNote)
    } else if (newNote && !existingNote) {
      newMain.insertAdjacentElement("afterend", newNote)
    } else if (!newNote && existingNote) {
      existingNote.remove()
    }
  }
}
