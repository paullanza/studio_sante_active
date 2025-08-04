import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["userSelect", "serviceSelect"]

  connect() {
    this.filter()
  }

  filter() {
    const selectedUserId = this.userSelectTarget.value

    this.serviceSelectTarget.querySelectorAll("option").forEach(option => {
      const userId = option.dataset.userId
      option.hidden = userId !== selectedUserId
    })

    // Optionally, reset selection if not valid
    if (
      this.serviceSelectTarget.selectedOptions.length === 0 ||
      this.serviceSelectTarget.selectedOptions[0].hidden
    ) {
      const firstVisibleOption = Array.from(this.serviceSelectTarget.options).find(
        opt => !opt.hidden
      )
      if (firstVisibleOption) this.serviceSelectTarget.value = firstVisibleOption.value
    }
  }
}
