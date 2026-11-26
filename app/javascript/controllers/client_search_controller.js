import { Controller } from "@hotwired/stimulus"

// A client field: fetches suggestions (fliip_users#suggest) into a Turbo
// frame as you type. On Saisir (the defaults) each suggestion reloads the page
// with that client chosen; in a consultation's link form, `url` carries the
// consultation and `frame` names that form's own suggestions frame.
export default class extends Controller {
  static targets = ["input"]
  static values = {
    url: { type: String, default: "/fliip_users/suggest" },
    frame: { type: String, default: "client_suggestions" }
  }

  connect() {
    this.timer = null
    this.lastQuery = ""
  }

  disconnect() {
    clearTimeout(this.timer)
  }

  search() {
    const q = this.inputTarget.value.trim()
    if (q === this.lastQuery) return
    this.lastQuery = q

    clearTimeout(this.timer)
    if (q.length < 2) { this.clear(); return }

    this.timer = setTimeout(() => {
      const frame = this.#frame()
      if (!frame) return
      const url = new URL(this.urlValue, window.location.origin)
      url.searchParams.set("query", q)
      frame.src = url.toString()
    }, 250)
  }

  // Enter opens the first suggestion.
  pickFirst(event) {
    event.preventDefault()
    this.#frame()?.querySelector("a.suggestion")?.click()
  }

  // Focus left the field and its suggestions.
  leave(event) {
    if (this.element.contains(event.relatedTarget)) return
    setTimeout(() => {
      if (!this.element.contains(document.activeElement)) this.clear()
    }, 150)
  }

  clear() {
    const frame = this.#frame()
    if (!frame) return // the page has gone (a suggestion was opened)
    frame.removeAttribute("src")
    frame.innerHTML = ""
    this.lastQuery = ""
  }

  #frame() {
    return document.getElementById(this.frameValue)
  }
}
