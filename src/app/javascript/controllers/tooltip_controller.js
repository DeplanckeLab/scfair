import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["text", "tooltip"]

  connect() {
    // Show tooltip only if text is truncated
    if (this.isTextTruncated()) {
      this.tooltipTarget.classList.add('group-hover:block')
    }
  }

  isTextTruncated() {
    const textElement = this.textTarget
    return textElement.scrollWidth > textElement.clientWidth
  }
} 