import { Controller } from "@hotwired/stimulus"

// Saisir's ticket: keeps the Récapitulatif in step with the form. Each output
// says what it shows through data attributes, joined with « · »:
//   data-summary-date="<input id>"    « mar. 24 nov. »  (SessionsHelper#ticket_day)
//   data-summary-time="<input id>"    « 17 h 00 »       (SessionsHelper#ticket_time)
//   data-summary-text="<id> <id>"     the inputs' values, joined with a space
//   data-summary-select="<select id>" the chosen option's text (« Moi (…) » reads « Moi »)
//   data-summary-radio="<name>"       the checked radio's data-summary-label, else its label text
//   data-summary-empty="…"            shown when nothing is filled in
export default class extends Controller {
  static targets = ["output"]

  static DAY = new Intl.DateTimeFormat("fr-CA", { weekday: "short", day: "numeric", month: "short" })

  connect() {
    this.update()
  }

  update() {
    this.outputTargets.forEach(output => {
      const d = output.dataset
      const parts = [
        d.summaryDate && this.#day(this.#value(d.summaryDate)),
        d.summaryTime && this.#value(d.summaryTime).replace(":", " h "),
        d.summaryText && d.summaryText.split(" ").map(id => this.#value(id).trim()).filter(Boolean).join(" "),
        d.summarySelect && this.#selected(d.summarySelect),
        d.summaryRadio && this.#radio(d.summaryRadio)
      ].filter(Boolean)
      output.textContent = parts.length ? parts.join(" · ") : (d.summaryEmpty || "")
    })
  }

  #value(id) {
    return document.getElementById(id)?.value || ""
  }

  #day(iso) {
    const [y, m, day] = iso.split("-").map(Number)
    if (!y || !m || !day) return ""
    return this.constructor.DAY.format(new Date(y, m - 1, day))
  }

  #selected(id) {
    const select = document.getElementById(id)
    const option = select?.selectedOptions[0]
    if (!option) return ""
    return option.value === "" ? option.text.replace(/\s*\(.*\)$/, "") : option.text
  }

  #radio(name) {
    const input = this.element.querySelector(`input[name="${name}"]:checked`)
    if (!input) return ""
    return input.dataset.summaryLabel || input.closest("label")?.textContent.trim() || ""
  }
}
