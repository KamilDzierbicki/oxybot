import { Controller } from "@hotwired/stimulus"

// Fills a hidden field with the browser's time zone, so a new workspace starts in the right zone
export default class extends Controller {
  static targets = ["field"]

  connect() {
    this.fieldTarget.value ||= Intl.DateTimeFormat().resolvedOptions().timeZone || ""
  }
}
