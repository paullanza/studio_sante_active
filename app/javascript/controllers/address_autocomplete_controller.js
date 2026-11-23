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

  // On the new layout the box sits inside a field tile (.field__box in
  // studio/_fields.scss) and the tile draws the focus and error underlines.
  // Mapbox's variables style both the box and its dropdown, so they are set
  // for the dropdown (a raised card with padded rows) and `cssText` strips
  // the box back to bare text on the tile. Mapbox also hard-codes a dark
  // input text colour that no variable reaches. The old Bootstrap layout has
  // no tokens and keeps Mapbox's light defaults.
  theme() {
    const styles = getComputedStyle(document.documentElement)
    const token = (name) => styles.getPropertyValue(name).trim()
    if (!token("--surface-2")) return { variables: { fontFamily: "inherit", borderRadius: "0.5rem" } }

    return {
      variables: {
        colorBackground: token("--surface"),
        colorBackgroundHover: token("--surface-2"),
        colorBackgroundActive: token("--surface-2"),
        colorText: token("--text"),
        colorSecondary: token("--text-muted"),
        colorPrimary: token("--accent"),
        border: `1px solid ${token("--border-strong")}`,
        borderRadius: token("--radius"),
        boxShadow: "0 16px 32px rgba(0, 0, 0, 0.45)",
        padding: "12px 16px",
        paddingFooterLabel: "10px 16px",
        lineHeight: "1.35",
        fontFamily: "Lato, sans-serif",
        unit: "17px"
      },
      cssText: `
        .SearchBox { padding: 0; border: 0; box-shadow: none; background: transparent; }
        .Input, .Input:focus { color: ${token("--text")}; height: 28px; padding: 0 32px 0 26px; border: 0; }
        .Input::placeholder { color: ${token("--text-muted")}; opacity: 1; }
        .SearchIcon { left: 0; fill: ${token("--text-muted")}; }
        .ClearBtn:hover { color: ${token("--text")}; }
        .Results { margin-top: 8px; overflow: hidden; }
        .Suggestion { color: ${token("--text-muted")}; font-size: 14px; }
        .Suggestion + .Suggestion { border-top: 1px solid ${token("--border")}; }
        .Suggestion[aria-selected=true] { box-shadow: inset 3px 0 0 ${token("--accent")}; }
        .SuggestionName { margin-bottom: 2px; color: ${token("--text")}; font-size: 16px; }
        .ResultsAttribution { border-top: 1px solid ${token("--border")}; font-size: 12px; }
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
