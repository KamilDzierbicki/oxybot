import { Controller } from "@hotwired/stimulus"

// Enter sends the question, Shift+Enter adds a new line
export default class extends Controller {
  submit(event) {
    if (event.key !== "Enter" || event.shiftKey || event.isComposing) return
    event.preventDefault()
    this.element.form.requestSubmit()
  }
}
