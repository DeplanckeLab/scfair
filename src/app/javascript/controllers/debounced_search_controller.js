import { Controller } from "@hotwired/stimulus"

// Handles debounced search input to prevent race conditions from rapid typing
export default class extends Controller {
  static values = {
    delay: { type: Number, default: 300 }
  }

  connect() {
    this.timeout = null
  }

  disconnect() {
    this.clearTimeout()
  }

  search() {
    this.clearTimeout()

    this.timeout = setTimeout(() => {
      this.element.form?.requestSubmit()
    }, this.delayValue)
  }

  submitNow(event) {
    if (event.key === 'Enter') {
      this.clearTimeout()
      this.element.form?.requestSubmit()
    }
  }

  clearTimeout() {
    if (this.timeout) {
      clearTimeout(this.timeout)
      this.timeout = null
    }
  }
}
