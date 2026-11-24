import { Controller } from "@hotwired/stimulus"

// Allocations page (allocations/index).
// - suggest: copies the séances read from the name into the queue's box.
// - track: marks a corrected value in gold and counts the changes.
// - confirm: before saving corrections, lists each change and asks.
export default class extends Controller {
  static targets = ["row", "count"]

  suggest({ params: { input, value } }) {
    const field = document.getElementById(input)
    if (!field) return

    field.value = value
    field.dispatchEvent(new Event("input", { bubbles: true }))
    field.focus()
  }

  track(event) {
    const field = event.target
    field.classList.toggle("is-changed", this.#isChanged(field))
    if (!this.hasCountTarget) return

    const n = this.#changedFields().length
    this.countTarget.textContent = n === 0
      ? "Aucune modification"
      : `${n} valeur${n > 1 ? "s" : ""} modifiée${n > 1 ? "s" : ""}`
  }

  confirm(event) {
    const lines = this.rowTargets.flatMap((row) => {
      const changes = [...row.querySelectorAll(".cell-input")]
        .filter((field) => this.#isChanged(field))
        .map((field) => `${this.#label(field)} ${field.dataset.original || "—"} → ${field.value || "vide"}`)
      if (changes.length === 0) return []

      const active = Number(row.dataset.active)
      const services = active === 0 ? "aucun service actif" : `${active} service${active > 1 ? "s" : ""} actif${active > 1 ? "s" : ""}`
      return [`• ${row.dataset.name} : ${changes.join(", ")} (${services})`]
    })

    if (lines.length === 0) {
      event.preventDefault()
      if (this.hasCountTarget) this.countTarget.textContent = "Aucune modification à enregistrer"
      return
    }

    const message = [
      `Enregistrer ${lines.length > 1 ? "ces corrections" : "cette correction"}?`,
      "",
      ...lines,
      "",
      "Les séances restantes des services actifs changent tout de suite."
    ].join("\n")
    if (!window.confirm(message)) event.preventDefault()
  }

  #isChanged(field) {
    return field.value.trim() !== (field.dataset.original || "")
  }

  #changedFields() {
    return [...this.element.querySelectorAll(".alloc-defined .cell-input")].filter((field) => this.#isChanged(field))
  }

  #label(field) {
    return field.name.endsWith("[paid_sessions]") ? "séances" : "absences"
  }
}
