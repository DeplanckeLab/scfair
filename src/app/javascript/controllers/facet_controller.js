import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button", "content", "item", "searchInput", "clearButton"]

  connect() {
    // Check if this facet has any checked checkboxes
    const hasCheckedBoxes = this.contentTarget.querySelectorAll('input[type="checkbox"]:checked').length > 0
    
    // Set initial state based on checked boxes
    if (hasCheckedBoxes) {
      this.contentTarget.style.maxHeight = this.contentTarget.scrollHeight + "px"
      this.buttonTarget.dataset.expanded = 'true'
      sessionStorage.setItem(`facet-${this.getFacetName()}`, 'true')
    } else {
      // If no checked boxes, use stored state or default to closed
      const isExpanded = sessionStorage.getItem(`facet-${this.getFacetName()}`) === 'true'
      this.contentTarget.style.maxHeight = isExpanded ? this.contentTarget.scrollHeight + "px" : "0px"
      this.buttonTarget.dataset.expanded = isExpanded ? 'true' : 'false'
    }
  }

  getFacetName() {
    return this.buttonTarget.querySelector('div').textContent.trim()
  }

  toggle(event) {
    const button = event.currentTarget
    const content = button.nextElementSibling
    const isExpanded = button.dataset.expanded === 'true'
    const facetName = this.getFacetName()

    // Close other facets that don't have checked items
    this.element.parentElement.querySelectorAll('[data-facet-target="content"]').forEach(el => {
      if (el !== content) {
        const hasCheckedBoxes = el.querySelectorAll('input[type="checkbox"]:checked').length > 0
        if (!hasCheckedBoxes) {
          const otherFacetName = el.previousElementSibling.querySelector('div').textContent.trim()
          el.style.maxHeight = '0px'
          el.previousElementSibling.dataset.expanded = 'false'
          sessionStorage.setItem(`facet-${otherFacetName}`, 'false')
        }
      }
    })

    // Toggle this facet
    if (isExpanded) {
      content.style.maxHeight = '0px'
      button.dataset.expanded = 'false'
      sessionStorage.setItem(`facet-${facetName}`, 'false')
    } else {
      content.style.maxHeight = content.scrollHeight + "px"
      button.dataset.expanded = 'true'
      sessionStorage.setItem(`facet-${facetName}`, 'true')
    }
  }

  filter(event) {
    const searchText = event.target.value.toLowerCase()
    this.itemTargets.forEach(item => {
      const value = item.dataset.value
      item.classList.toggle('hidden', value.indexOf(searchText) === -1)
    })

    // Show/hide clear button
    this.clearButtonTarget.style.display = searchText.length > 0 ? 'block' : 'none'

    // Update content height if expanded
    if (this.buttonTarget.dataset.expanded === 'true') {
      this.contentTarget.style.maxHeight = this.contentTarget.scrollHeight + "px"
    }
  }

  clearSearch(event) {
    this.searchInputTarget.value = ''
    this.itemTargets.forEach(item => item.classList.remove('hidden'))
    this.clearButtonTarget.style.display = 'none'
    
    // Update content height if expanded
    if (this.buttonTarget.dataset.expanded === 'true') {
      this.contentTarget.style.maxHeight = this.contentTarget.scrollHeight + "px"
    }
  }
} 
