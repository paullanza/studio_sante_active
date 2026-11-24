import { Controller } from "@hotwired/stimulus"

// Saisir's client field: fetches suggestions (fliip_users#suggest) into the
// client_suggestions frame as you type. Each suggestion is a link that
// reloads the page with that client chosen.
export default class extends Controller {
  static targets = ["input"]

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
      if (frame) frame.src = `/fliip_users/suggest?query=${encodeURIComponent(q)}`
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
    return document.getElementById("client_suggestions")
  }
}
