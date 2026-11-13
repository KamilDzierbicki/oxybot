import { Controller } from "@hotwired/stimulus"

// Keeps a destructive button disabled until the exact name is typed. The server checks the name again.
export default class extends Controller {
  static targets = ["input", "button"]
  static values = { expected: String }

  connect() {
    this.check()
  }

  check() {
    this.buttonTarget.disabled = this.inputTarget.value !== this.expectedValue
  }
}
