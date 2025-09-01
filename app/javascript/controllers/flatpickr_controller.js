import { Controller } from "@hotwired/stimulus"
import flatpickr from "flatpickr"
// import { French } from "flatpickr/dist/l10n/fr.js"

export default class extends Controller {
  static targets = [
    // Range pickers (visible inputs)
    "sessionRange", "createdRange",
    // Range pickers (hidden fields Rails reads)
    "sessionFromHidden", "sessionToHidden",
    "createdFromHidden", "createdToHidden",
    // Single pickers
    "date", "time"
  ]

  connect() {
    // Common date config (calendar)
    const baseDate = {
      // locale: French,
      dateFormat: "Y-m-d",   // value submitted to Rails
      altInput: true,        // pretty visible value
      altFormat: "d/m/Y",
      allowInput: true,
      disableMobile: true
    }

    // Range config extends date config
    const baseRange = { ...baseDate, mode: "range" }

    // Time-only config (no calendar)
    const baseTime = {
      enableTime: true,
      noCalendar: true,
      dateFormat: "H:i",
      time_24hr: true,
      allowInput: true,
      disableMobile: false,
      minuteIncrement: 15,
      minTime: "6:00",
      maxTime: "20:45",
    }

    // --- Session RANGE ---
    if (this.hasSessionRangeTarget) {
      this.sessionPicker = flatpickr(this.sessionRangeTarget, {
        ...baseRange,
        onChange: (dates) =>
          this._assignRange(dates, this.sessionFromHiddenTarget, this.sessionToHiddenTarget)
      })
      this._hydrateRangeFromHidden(
        this.sessionPicker,
        this.sessionFromHiddenTarget?.value,
        this.sessionToHiddenTarget?.value
      )
    }

    // --- Created RANGE ---
    if (this.hasCreatedRangeTarget) {
      this.createdPicker = flatpickr(this.createdRangeTarget, {
        ...baseRange,
        onChange: (dates) =>
          this._assignRange(dates, this.createdFromHiddenTarget, this.createdToHiddenTarget)
      })
      this._hydrateRangeFromHidden(
        this.createdPicker,
        this.createdFromHiddenTarget?.value,
        this.createdToHiddenTarget?.value
      )
    }

    // --- Single DATE ---
    if (this.hasDateTarget) {
      this.datePicker = flatpickr(this.dateTarget, baseDate)
    }

    // --- Single TIME ---
    if (this.hasTimeTarget) {
      this.timePicker = flatpickr(this.timeTarget, baseTime)
    }
  }

  // Assigns YYYY-MM-DD into hidden from/to fields for a range
  _assignRange(dates, fromHidden, toHidden) {
    if (fromHidden) fromHidden.value = dates[0] ? this._fmtYmd(dates[0]) : ""
    if (toHidden)   toHidden.value   = dates[1] ? this._fmtYmd(dates[1]) : ""
  }

  // Hydrates a range picker’s visible input from hidden from/to values
  _hydrateRangeFromHidden(picker, from, to) {
    if (!picker || (!from && !to)) return
    const start = from ? new Date(from) : null
    const end   = to   ? new Date(to)   : null
    const sel   = end ? [start, end] : (start ? [start] : [])
    if (sel.length > 0) picker.setDate(sel, true) // true → sync altInput
  }

  _fmtYmd(d) {
    const pad = (n) => String(n).padStart(2, "0")
    return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`
  }

  disconnect() {
    this.sessionPicker?.destroy()
    this.createdPicker?.destroy()
    this.datePicker?.destroy()
    this.timePicker?.destroy()
  }
}
