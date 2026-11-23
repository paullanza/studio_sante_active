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
    this.searchBox.theme = { variables: this.themeVariables() }

    // sync hidden field on select/clear
    this.handleRetrieve = this.handleRetrieve.bind(this)
    this.handleClear = this.handleClear.bind(this)
    this.searchBox.addEventListener("retrieve", this.handleRetrieve)
    this.searchBox.addEventListener("clear", this.handleClear)

    // Right after the hidden input, so a field error below it stays below the box.
    this.addressTarget.after(this.searchBox)

    // Prefill visually with the saved address; setting value doesn't open suggestions
    const existing = (this.addressTarget.value || "").trim()
    if (existing) this.searchBox.value = existing
  }

  disconnect() {
    this.searchBox?.removeEventListener("retrieve", this.handleRetrieve)
    this.searchBox?.removeEventListener("clear", this.handleClear)
    this.searchBox?.remove()
  }

  // On the new layout, colours come from the design tokens (docs/ui.md) so the
  // box reads on the dark theme. The old Bootstrap layout has no tokens and
  // keeps Mapbox's light defaults.
  themeVariables() {
    const styles = getComputedStyle(document.documentElement)
    const token = (name) => styles.getPropertyValue(name).trim()
    if (!token("--surface-2")) return { fontFamily: "inherit", borderRadius: "0.5rem" }

    return {
      colorBackground: token("--surface-2"),
      colorBackgroundHover: token("--surface"),
      colorText: token("--text"),
      colorPrimary: token("--accent"),
      border: `1px solid ${token("--border")}`,
      borderRadius: token("--radius"),
      fontFamily: "Lato, sans-serif"
    }
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
