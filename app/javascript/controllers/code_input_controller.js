import { Controller } from "@hotwired/stimulus"

// One cell per character of a fixed-length code (StudioFormBuilder#code).
// Typing moves to the next cell, Backspace on an empty cell goes back, and
// pasting fills every cell. The joined value goes into the hidden input,
// which is the only one that submits.
export default class extends Controller {
  static targets = ["cell", "value"]

  input(event) {
    const cell = event.target
    cell.value = this.clean(cell.value).slice(-1)
    if (cell.value) this.cellAfter(cell)?.focus()
    this.sync()
  }

  keydown(event) {
    const cell = event.target
    if (event.key === "Backspace" && !cell.value) {
      event.preventDefault()
      const previous = this.cellBefore(cell)
      if (previous) {
        previous.value = ""
        previous.focus()
        this.sync()
      }
    } else if (event.key === "ArrowLeft") {
      this.cellBefore(cell)?.focus()
    } else if (event.key === "ArrowRight") {
      this.cellAfter(cell)?.focus()
    }
  }

  paste(event) {
    const text = this.clean(event.clipboardData?.getData("text") || "")
    if (!text) return

    event.preventDefault()
    this.cellTargets.forEach((cell, index) => { cell.value = text[index] || "" })
    this.cellTargets[Math.min(text.length, this.cellTargets.length - 1)].focus()
    this.sync()
  }

  select(event) {
    event.target.select()
  }

  // Codes are uppercase letters and digits (SignupCode#generate_code).
  clean(text) {
    return text.toUpperCase().replace(/[^A-Z0-9]/g, "")
  }

  sync() {
    this.valueTarget.value = this.cellTargets.map((cell) => cell.value).join("")
  }

  cellAfter(cell) {
    return this.cellTargets[this.cellTargets.indexOf(cell) + 1]
  }

  cellBefore(cell) {
    return this.cellTargets[this.cellTargets.indexOf(cell) - 1]
  }
}
