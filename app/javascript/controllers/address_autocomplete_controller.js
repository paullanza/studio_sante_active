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
    this.searchBox.theme = this.theme()

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

  // On the new layout the box matches the other inputs (.field__input in
  // studio/_fields.scss), from the design tokens. Mapbox hard-codes a dark
  // input text colour that no theme variable reaches, so `cssText` overrides
  // it inside the shadow DOM. The old Bootstrap layout has no tokens and
  // keeps Mapbox's light defaults.
  theme() {
    const styles = getComputedStyle(document.documentElement)
    const token = (name) => styles.getPropertyValue(name).trim()
    if (!token("--surface-2")) return { variables: { fontFamily: "inherit", borderRadius: "0.5rem" } }

    const invalid = this.element.classList.contains("field--invalid")
    const border = token(invalid ? "--field-invalid-border" : "--border")

    return {
      variables: {
        colorBackground: token("--bg"),
        colorBackgroundHover: token("--surface-2"),
        colorBackgroundActive: token("--surface-2"),
        colorText: token("--text"),
        colorSecondary: token("--text-muted"),
        colorPrimary: token("--accent"),
        border: `1px solid ${border}`,
        borderRadius: token("--radius"),
        boxShadow: "none",
        fontFamily: "Lato, sans-serif",
        unit: "16px"
      },
      cssText: `
        .Input, .Input:focus { color: ${token("--text")}; height: calc(${token("--control-height")} - 2px); border: 0; }
        .Input::placeholder { color: ${token("--text-muted")}; opacity: 1; }
        .SearchIcon { fill: ${token("--text-muted")}; }
        .ClearBtn:hover { color: ${token("--text")}; }
        .SearchBox:focus-within { border-color: ${token("--border-strong")}; outline: 2px solid ${token("--border-strong")}; }
      `
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
