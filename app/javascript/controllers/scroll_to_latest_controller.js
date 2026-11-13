import { Controller } from "@hotwired/stimulus"

// Keeps the newest message in view when Turbo Streams append or replace messages
export default class extends Controller {
  connect() {
    const behavior = window.matchMedia("(prefers-reduced-motion: reduce)").matches ? "auto" : "smooth"
    this.observer = new MutationObserver(() => this.element.lastElementChild?.scrollIntoView({ behavior, block: "end" }))
    this.observer.observe(this.element, { childList: true, subtree: true })
  }

  disconnect() {
    this.observer.disconnect()
  }
}
