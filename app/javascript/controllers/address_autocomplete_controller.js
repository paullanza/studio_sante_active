import { Controller } from "@hotwired/stimulus"
import "@mapbox/search-js-web"

export default class extends Controller {
  static values = { apiKey: String }
  static targets = ["address"]   // hidden Rails input

  async connect() {
    // The module import registers <mapbox-search-box>; wait in case we got here first.
    await customElements.whenDefined("mapbox-search-box")

    this.searchBox = document.createElement("mapbox-search-box")
    this.searchBox.accessToken = this.apiKeyValue
    this.searchBox.options = {
      language: "fr",
      country: "ca",
      types: ["country", "region", "place", "postcode", "locality", "neighborhood", "address"]
    }
    this.searchBox.placeholder = "Adresse"
    this.searchBox.theme = { variables: { fontFamily: "inherit", borderRadius: "0.5rem" } }

    // sync hidden field on select/clear
    this.handleRetrieve = this.handleRetrieve.bind(this)
    this.handleClear = this.handleClear.bind(this)
    this.searchBox.addEventListener("retrieve", this.handleRetrieve)
    this.searchBox.addEventListener("clear", this.handleClear)

    this.element.appendChild(this.searchBox)

    // Prefill visually with the saved address; setting value doesn't open suggestions
    const existing = (this.addressTarget.value || "").trim()
    if (existing) this.searchBox.value = existing
  }

  disconnect() {
    this.searchBox?.removeEventListener("retrieve", this.handleRetrieve)
    this.searchBox?.removeEventListener("clear", this.handleClear)
    this.searchBox?.remove()
  }

  handleRetrieve(event) {
    const feature = event.detail.features[0]
    if (!feature) return

    this.addressTarget.value = feature.properties.full_address || feature.properties.name
  }

  handleClear() {
    this.addressTarget.value = ""
  }
}
