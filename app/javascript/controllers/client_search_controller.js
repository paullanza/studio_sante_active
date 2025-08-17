import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "hiddenId"]

  connect() {
    this.timer = null
    this.lastQuery = ""
  }

  onInput() {
    const q = this.inputTarget.value.trim()
    if (q === this.lastQuery) return
    this.lastQuery = q

    clearTimeout(this.timer)
    if (q.length < 2) { this.#clearSuggestions(); return }

    this.timer = setTimeout(() => {
      const url = `/fliip_users/suggest?query=${encodeURIComponent(q)}`
      this.#setFrameSrc("client_suggestions", url)
    }, 250)
  }

  onFocus() {
    if (this.inputTarget.value.trim().length >= 2 && !this.#frameHasContent("client_suggestions")) {
      const url = `/fliip_users/suggest?query=${encodeURIComponent(this.inputTarget.value.trim())}`
      this.#setFrameSrc("client_suggestions", url)
    }
  }

  onBlur() {
    // Slight delay so clicks register
    setTimeout(() => this.#clearSuggestions(), 150)
  }

  // Called from <li data-action="click->client-search#pick" ...>
  pick(event) {
    const el = event.currentTarget
    const id = el.dataset.id
    const name = el.dataset.name

    this.hiddenIdTarget.value = id
    this.inputTarget.value = name

    this.#clearSuggestions()

    // Kick both frames to server-render HTML
    this.#setFrameSrc("services_table", `/sessions/services_table?fliip_user_id=${encodeURIComponent(id)}`)
    this.#setFrameSrc("service_select", `/sessions/service_select?fliip_user_id=${encodeURIComponent(id)}`)
  }

  preventSubmit(event) {
    event.preventDefault()
    event.stopPropagation()
  }

  // --- helpers ---
  #clearSuggestions() {
    const frame = document.getElementById("client_suggestions")
    if (frame) frame.innerHTML = ""
  }

  #setFrameSrc(id, url) {
    const frame = document.getElementById(id)
    if (frame) frame.src = url
  }

  #frameHasContent(id) {
    const frame = document.getElementById(id)
    if (!frame) return false
    return frame.innerHTML.trim().length > 0
  }
}
