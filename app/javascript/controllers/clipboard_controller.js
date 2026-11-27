import { Controller } from "@hotwired/stimulus"

// Copies the source's text; the button says « Copié » for a moment.
export default class extends Controller {
  static targets = ["source", "button"]

  disconnect() {
    clearTimeout(this.timer)
  }

  async copy() {
    try {
      await navigator.clipboard.writeText(this.sourceTarget.textContent.trim())
    } catch {
      return
    }
    const label = this.buttonTarget.dataset.label || this.buttonTarget.textContent
    this.buttonTarget.dataset.label = label
    this.buttonTarget.textContent = "Copié"
    clearTimeout(this.timer)
    this.timer = setTimeout(() => { this.buttonTarget.textContent = label }, 2000)
  }
}
