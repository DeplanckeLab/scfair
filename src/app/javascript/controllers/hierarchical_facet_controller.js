import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["content", "searchInput", "clearButton", "selectedCount", "items", "item", "checkbox", "button"]
  
  connect() {
    this.updateSelectedCount()
  }
  
  toggle(event) {
    event.preventDefault()
    
    try {
      if (!this.hasContentTarget) return
      
      const contentEl = this.contentTarget
      
      if (this.hasButtonTarget) {
        const buttonEl = this.buttonTarget
        
        const chevron = buttonEl.querySelector('svg')
        if (chevron) {
          chevron.classList.toggle('rotate-180')
        }
      }
      
      if (contentEl.style.maxHeight === 'none' || contentEl.style.maxHeight === '') {
        contentEl.style.maxHeight = '0px'
      } else {
        contentEl.style.maxHeight = 'none'
      }
    } catch (error) {
      console.error("Error in toggle method:", error)
    }
  }
  
  handleSelection(event) {
    const checkbox = event.target
    const checked = checkbox.checked
    const level = parseInt(checkbox.dataset.level || "0")
    const item = checkbox.closest('[data-hierarchical-facet-target="item"]')
    const itemValue = item.dataset.value
    
    if (checked) {
      this.selectChildren(itemValue, level)
    } else {
      this.deselectChildren(itemValue, level)
      if (level > 0) {
        this.deselectParent(itemValue)
      }
    }
    
    this.submitForm()
    this.updateSelectedCount()
  }
  
  selectChildren(parentValue, parentLevel) {
    this.itemTargets.forEach(childItem => {
      const childLevel = parseInt(childItem.dataset.level || "0")
      const childValue = childItem.dataset.value
      
      if (childLevel > parentLevel && childValue.startsWith(`${parentValue} `)) {
        const childCheckbox = childItem.querySelector('[data-hierarchical-facet-target="checkbox"]')
        if (childCheckbox && !childCheckbox.checked) {
          childCheckbox.checked = true
        }
      }
    })
  }
  
  deselectChildren(parentValue, parentLevel) {
    this.itemTargets.forEach(childItem => {
      const childLevel = parseInt(childItem.dataset.level || "0")
      const childValue = childItem.dataset.value
      
      if (childLevel > parentLevel && childValue.startsWith(`${parentValue} `)) {
        const childCheckbox = childItem.querySelector('[data-hierarchical-facet-target="checkbox"]')
        if (childCheckbox && childCheckbox.checked) {
          childCheckbox.checked = false
        }
      }
    })
  }
  
  deselectParent(childValue) {
    this.itemTargets.forEach(parentItem => {
      const parentLevel = parseInt(parentItem.dataset.level || "0")
      const parentValue = parentItem.dataset.value
      
      if (parentLevel === 0 && childValue.startsWith(`${parentValue} `)) {
        const parentCheckbox = parentItem.querySelector('[data-hierarchical-facet-target="checkbox"]')
        if (parentCheckbox && parentCheckbox.checked) {
          parentCheckbox.checked = false
        }
      }
    })
  }
  
  filter(event) {
    const searchInput = this.searchInputTarget
    const query = searchInput.value.toLowerCase().trim()
    
    this.clearButtonTarget.style.display = query ? "block" : "none"
    
    if (!query) {
      this.itemTargets.forEach(item => {
        item.classList.remove("hidden")
      })
      return
    }
    
    const matchingItems = new Set()
    const parentItems = new Set()
    
    this.itemTargets.forEach(item => {
      const value = item.dataset.value.toLowerCase()
      
      if (value.includes(query)) {
        matchingItems.add(item)
        
        if (parseInt(item.dataset.level) > 0) {
          this.itemTargets.forEach(potentialParent => {
            const parentValue = potentialParent.dataset.value
            if (value.startsWith(`${parentValue.toLowerCase()} `)) {
              parentItems.add(potentialParent)
            }
          })
        }
      }
    })
    
    this.itemTargets.forEach(item => {
      if (matchingItems.has(item) || parentItems.has(item)) {
        item.classList.remove("hidden")
      } else {
        item.classList.add("hidden")
      }
    })
  }
  
  showParents(item) {
    const level = parseInt(item.dataset.level || "0")
    if (level === 0) return
    
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
