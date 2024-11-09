import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["content", "summary"]

  toggle() {
    this.contentTarget.classList.toggle("hidden")
    this.summaryTarget.classList.toggle("hidden")
  }
} 