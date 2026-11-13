import { Controller } from "@hotwired/stimulus"

// Submits the surrounding form when a field changes (toggles that save on click)
export default class extends Controller {
  submit() {
    this.element.requestSubmit()
  }
}
