import { Controller } from "@hotwired/stimulus"
import MapboxGeocoder from "@mapbox/mapbox-gl-geocoder"

export default class extends Controller {
  static values = { apiKey: String }
  static targets = ["address"]   // hidden Rails input

  connect() {
    this.geocoder = new MapboxGeocoder({
      accessToken: this.apiKeyValue,
      placeholder: "Adresse",
      language: "fr,en",
      types: "country,region,place,postcode,locality,neighborhood,address",
      countries: "ca",
      // keep defaults; don't use setInput() here
    })

    this.geocoder.addTo(this.element)

    // sync hidden field on select/clear
    this.geocoder.on("result", (e) => { this.addressTarget.value = e.result.place_name })
    this.geocoder.on("clear", () => { this.addressTarget.value = "" })

    // ✅ Prefill visually without opening suggestions
    const existing = (this.addressTarget.value || "").trim()
    if (existing) {
      // grab the actual text input the plugin creates
      this.inputEl = this.element.querySelector(".mapboxgl-ctrl-geocoder--input")
      if (this.inputEl) this.inputEl.value = existing // no 'input' event => no dropdown
    }
  }

  disconnect() { this.geocoder?.onRemove() }
}
