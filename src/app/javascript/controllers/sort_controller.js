import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["form"]

  apply() {
    if (!this.hasFormTarget) return
    const pageInput = this.formTarget.querySelector('input[name="page"]')
    if (pageInput) pageInput.value = "1"
    this.formTarget.requestSubmit()
  }
}


