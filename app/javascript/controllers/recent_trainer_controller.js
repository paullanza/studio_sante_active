import { Controller } from "@hotwired/stimulus"

// Saisir: when an admin changes the trainer, reloads the side list
// (the recent_sessions Turbo frame) with that trainer's latest séances.
export default class extends Controller {
  static values = { url: String }

  reload(event) {
    const frame = document.getElementById("recent_sessions")
    if (!frame) return

    const url = new URL(this.urlValue, window.location.origin)
    if (event.target.value) url.searchParams.set("trainer_id", event.target.value)
    frame.src = url.toString()
  }
}
