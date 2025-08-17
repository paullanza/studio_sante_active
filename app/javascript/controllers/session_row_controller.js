import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["display", "form", "date", "time", "present", "note", "halfHour", "userId"]
  static values = { updateUrl: String, deleteUrl: String }

  connect() {
    this.csrfToken = document.querySelector('meta[name="csrf-token"]')?.content
  }

  edit()   { this.displayTarget.classList.add("d-none"); this.formTarget.classList.remove("d-none") }
  cancel() { this.formTarget.classList.add("d-none");    this.displayTarget.classList.remove("d-none") }

  async save() {
    const body = {
      session: {
        date:      this.dateTarget.value,
        time:      this.timeTarget.value,
        present:   this.presentTarget.checked ? "1" : "0",
        note:      this.noteTarget.value,
        half_hour: this.halfHourTarget.checked ? "1" : "0"
      }
    }

    // If the select exists (admins only), include user_id
    if (this.hasUserIdTarget) {
      body.session.user_id = this.userIdTarget.value
    }

    const res = await fetch(this.updateUrlValue, {
      method: "PATCH",
      headers: { "Content-Type": "application/json", "X-CSRF-Token": this.csrfToken, "Accept": "application/json" },
      body: JSON.stringify(body)
    })

    if (!res.ok) {
      const data = await res.json().catch(() => ({}))
      alert(data.errors ? data.errors.join(", ") : "Update failed")
      return
    }

    const data = await res.json()
    this.element.querySelector("[data-field='date']").textContent    = data.date || "—"
    this.element.querySelector("[data-field='time']").textContent    = data.time || "—"
    this.element.querySelector("[data-field='present']").textContent = data.present ? "Oui" : "Non"
    this.element.querySelector("[data-field='note']").textContent    = data.note || "–"
    this.cancel()
  }

  async delete() {
    if (!confirm("Delete this session? This cannot be undone.")) return
    const res = await fetch(this.deleteUrlValue, {
      method: "DELETE",
      headers: { "X-CSRF-Token": this.csrfToken, "Accept": "application/json" }
    })
    if (res.status === 204)      this.element.remove()
    else if (res.status === 403) alert("You don't have permission to delete sessions.")
    else                         alert("Delete failed")
  }
}
