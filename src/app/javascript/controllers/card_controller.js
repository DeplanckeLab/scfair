import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["content", "summary"]

  toggle() {
    this.contentTarget.classList.toggle("hidden")
    this.summaryTarget.classList.toggle("hidden")
    this.element.classList.toggle("hover:bg-gray-50")
    this.element.classList.toggle("bg-white")
  }
} 
