import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dialog", "title", "body", "footer", "confirm", "cancel"]

  connect() {
    this._onOpen = this._onOpen.bind(this)
    this.element.addEventListener("modal:open", this._onOpen)
    this._confirmHandler = null
    this.bs = window.bootstrap?.Modal?.getOrCreateInstance(this.element, { backdrop: true, keyboard: true })

    this.element.addEventListener("hidden.bs.modal", () => {
      this._teardownConfirm()
      this._setTitle("")
      this._setBody("")
      this._setPrimaryLabel("Continuer")
      this._setSecondaryLabel("Annuler")
      this._setSize(null)
    })
  }

  disconnect() {
    this.element.removeEventListener("modal:open", this._onOpen)
    this._teardownConfirm()
    if (this.bs) this.bs.hide()
  }

  _onOpen(e) {
    const {
      title = "",
      body = "",
      primaryLabel = "Continuer",
      secondaryLabel = "Annuler",
      size = null,
      onConfirm = null
    } = e.detail || {}

    this._setTitle(title)
    this._setBody(body)
    this._setPrimaryLabel(primaryLabel)
    this._setSecondaryLabel(secondaryLabel)
    this._setSize(size)

    this._teardownConfirm()
    if (onConfirm) {
      this._confirmHandler = () => {
        try { onConfirm() } finally { this.bs?.hide() }
      }
      this.confirmTarget.addEventListener("click", this._confirmHandler, { once: true })
    } else {
      this._confirmHandler = () => this.bs?.hide()
      this.confirmTarget.addEventListener("click", this._confirmHandler, { once: true })
    }

    this.bs?.show()
  }

  _setTitle(text) { if (this.hasTitleTarget) this.titleTarget.textContent = text || "" }
  _setBody(htmlOrText) {
    if (!this.hasBodyTarget) return
    if (/<[a-z][\s\S]*>/i.test(htmlOrText)) {
      this.bodyTarget.innerHTML = htmlOrText
    } else {
      this.bodyTarget.textContent = htmlOrText
    }
  }
  _setPrimaryLabel(text) { if (this.hasConfirmTarget) this.confirmTarget.textContent = text || "Continuer" }
  _setSecondaryLabel(text) { if (this.hasCancelTarget) this.cancelTarget.textContent = text || "Annuler" }

  _setSize(size) {
    if (!this.hasDialogTarget) return
    const dlg = this.dialogTarget
    dlg.classList.remove("modal-sm", "modal-lg", "modal-xl")
    if (size === "sm") dlg.classList.add("modal-sm")
    if (size === "lg") dlg.classList.add("modal-lg")
    if (size === "xl") dlg.classList.add("modal-xl")
  }

  _teardownConfirm() {
    if (this._confirmHandler && this.hasConfirmTarget) {
      this.confirmTarget.removeEventListener("click", this._confirmHandler)
    }
    this._confirmHandler = null
  }
}
