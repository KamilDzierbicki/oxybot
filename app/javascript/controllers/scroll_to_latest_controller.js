import { Controller } from "@hotwired/stimulus"

// Keeps the newest message in view when Turbo Streams append or replace messages
export default class extends Controller {
  connect() {
    this.observer = new MutationObserver(() => this.element.lastElementChild?.scrollIntoView({ behavior: "smooth", block: "end" }))
    this.observer.observe(this.element, { childList: true, subtree: true })
  }

  disconnect() {
    this.observer.disconnect()
  }
}
