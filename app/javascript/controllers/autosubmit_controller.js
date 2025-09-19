import { Controller } from "@hotwired/stimulus";

// Submits the nearest form when any field inside changes.
// Keep it dead simple for reliability.
export default class extends Controller {
  submit(event) {
    const form = event.target?.form || this.element.closest("form") || this.element;
    if (form && typeof form.requestSubmit === "function") {
      form.requestSubmit(); // respects <button type="submit"> defaults
    } else if (form) {
      form.submit();
    }
  }
}
