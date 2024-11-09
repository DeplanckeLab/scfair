import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["items", "item", "button", "content", "searchInput", "clearButton"]

  connect() {
    if (this.hasItemsTarget) {
      this.sortItems()
    }
  }

  toggle() {
    const content = this.contentTarget
    const isCollapsed = content.style.maxHeight === '0px'
    
    if (isCollapsed) {
      this.expand()
    } else {
      this.collapse()
    }
  }

  expand() {
    this.contentTarget.style.maxHeight = 'none'
    this.buttonTarget.querySelector('svg').classList.add('rotate-180')
  }

  collapse() {
    this.contentTarget.style.maxHeight = '0px'
    this.buttonTarget.querySelector('svg').classList.remove('rotate-180')
  }

  submitForm(event) {
    event.preventDefault()
    const checkbox = event.target
    
    if (checkbox.checked) {
      this.appendToSelectedItems(checkbox)
    } else {
      this.moveToUnselected(checkbox)
    }
    
    // Keep accordion open after form submission
    this.expand()
    
    setTimeout(() => {
      event.target.closest('form').requestSubmit()
    }, 0)
  }

  getFacetName() {
    return this.buttonTarget.querySelector('div').textContent.trim()
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
