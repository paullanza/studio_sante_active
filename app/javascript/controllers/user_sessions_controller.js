import { Controller } from "@hotwired/stimulus"

// Connect this to the <select> via data-controller="user-sessions"
// Expected values on the element:
//   data-user-sessions-url-value   -> e.g., "/sessions/recent"
//   data-user-sessions-frame-value -> the Turbo Frame id (e.g., "recent_sessions_frame")
//   data-user-sessions-current-user-value -> current_user.id (fallback when select is blank)
//
// Expected action:
//   data-action="change->user-sessions#load"
export default class extends Controller {
  static values = {
    url: String,
    frame: String,
    currentUser: Number
  }

  // Triggered on select change
  load() {
    const userId = this.element.value || String(this.currentUserValue || "")
    const frame = document.getElementById(this.frameValue)
    if (!frame || !this.urlValue) return

    const url = new URL(this.urlValue, window.location.origin)
    if (userId) {
      url.searchParams.set("user_id", userId)
    } else {
      // Let the controller action fall back to current_user
      url.searchParams.delete("user_id")
    }

    // Optional: show loading state to assistive tech
    frame.setAttribute("aria-busy", "true")

    // Reload the Turbo Frame with the new src
    frame.setAttribute("src", url.toString())
  }
}
