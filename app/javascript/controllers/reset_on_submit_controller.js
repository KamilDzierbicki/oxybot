import { Controller } from "@hotwired/stimulus"

// Clears a form after a successful submit without replacing it, so focus stays where the person is typing
export default class extends Controller {
  reset(event) {
    if (event.detail.success) this.element.reset()
  }
}
