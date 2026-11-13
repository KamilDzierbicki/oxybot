import { Controller } from "@hotwired/stimulus"

// Warns before leaving a long form with unsaved typing (reload, Back, or a Turbo link)
export default class extends Controller {
  connect() {
    this.dirty = false
    this.markDirty = () => { this.dirty = true }
    this.warn = (event) => {
      if (!this.dirty) return
      event.preventDefault()
      event.returnValue = ""
    }
    this.confirmVisit = (event) => {
      if (this.dirty && !window.confirm("You have unsaved changes. Leave this page?")) event.preventDefault()
    }
    this.element.addEventListener("input", this.markDirty)
    this.element.addEventListener("submit", () => { this.dirty = false })
    window.addEventListener("beforeunload", this.warn)
    document.addEventListener("turbo:before-visit", this.confirmVisit)
  }

  disconnect() {
    window.removeEventListener("beforeunload", this.warn)
    document.removeEventListener("turbo:before-visit", this.confirmVisit)
  }
}
