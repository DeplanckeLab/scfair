import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dropdown"]

  connect() {
    this.positionDropdown()
  }

  positionDropdown() {
    const dropdown = this.dropdownTarget
    const button = dropdown.previousElementSibling
    const buttonRect = button.getBoundingClientRect()
    const viewportHeight = window.innerHeight
    const spaceAbove = buttonRect.top
    const spaceBelow = viewportHeight - buttonRect.bottom
    
    // Reset any previous positioning
    dropdown.style.removeProperty('bottom')
    dropdown.style.removeProperty('top')
    dropdown.style.removeProperty('max-height')
    
    if (spaceBelow >= 300 || spaceBelow > spaceAbove) {
      // Open downwards
      dropdown.style.top = '100%'
      dropdown.style.maxHeight = `${spaceBelow - 20}px`
    } else {
      // Open upwards
      dropdown.style.bottom = '100%'
      dropdown.style.maxHeight = `${spaceAbove - 20}px`
    }
  }
} 