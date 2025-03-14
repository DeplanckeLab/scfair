import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button", "content", "searchInput", "clearButton", "selectedCount", "items", "item", "checkbox"]
  
  toggle() {
    const content = this.contentTarget
    const isHidden = content.style.maxHeight === "0px"
    
    if (isHidden) {
      content.style.maxHeight = "none"
    } else {
      content.style.maxHeight = "0px"
    }
  }
  
  handleSelection(event) {
    const checkbox = event.target
    const checked = checkbox.checked
    const level = parseInt(checkbox.dataset.level || "0")
    
    // When a parent is checked/unchecked, apply to all children
    if (checked) {
      // Select all descendants (items with higher level)
      this.checkboxTargets.forEach(childBox => {
        const childLevel = parseInt(childBox.dataset.level || "0")
        if (childLevel > level) {
          childBox.checked = true
        }
      })
    }
    
    // Submit the form to apply the selection
    this.submitForm()
    
    // Update selected count
    this.updateSelectedCount()
  }
  
  filter(event) {
    const searchInput = this.searchInputTarget
    const query = searchInput.value.toLowerCase()
    
    this.clearButtonTarget.style.display = query ? "block" : "none"
    
    this.itemTargets.forEach(item => {
      const value = item.dataset.value.toLowerCase()
      if (value.includes(query)) {
        item.classList.remove("hidden")
        
        // Also show parents
        this.showParents(item)
      } else {
        item.classList.add("hidden")
      }
    })
  }
  
  showParents(item) {
    const level = parseInt(item.dataset.level || "0")
    if (level === 0) return
    
    // Find and show all parent items (items with lower level)
    this.itemTargets.forEach(parentItem => {
      const parentLevel = parseInt(parentItem.dataset.level || "0")
      if (parentLevel < level) {
        parentItem.classList.remove("hidden")
      }
    })
  }
  
  clearSearch() {
    this.searchInputTarget.value = ""
    this.clearButtonTarget.style.display = "none"
    
    this.itemTargets.forEach(item => {
      item.classList.remove("hidden")
    })
  }
  
  updateSelectedCount() {
    const checkedBoxes = this.element.querySelectorAll('input[type="checkbox"]:checked')
    this.selectedCountTarget.textContent = checkedBoxes.length > 0 ? `${checkedBoxes.length} selected` : ""
    this.selectedCountTarget.classList.toggle("hidden", checkedBoxes.length === 0)
  }
  
  showClearAll(event) {
    event.target.textContent = "Clear all"
  }
  
  restoreSelectedCount(event) {
    this.updateSelectedCount()
  }
  
  clearAllSelected(event) {
    event.preventDefault()
    event.stopPropagation()
    
    const checkboxes = this.element.querySelectorAll('input[type="checkbox"]:checked')
    checkboxes.forEach(checkbox => {
      checkbox.checked = false
    })
    
    this.submitForm()
    this.updateSelectedCount()
  }
  
  stopPropagation(event) {
    event.stopPropagation()
  }
  
  submitForm() {
    this.element.closest("form").requestSubmit()
  }
}