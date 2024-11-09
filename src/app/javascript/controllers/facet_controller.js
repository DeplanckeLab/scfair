import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["items", "item", "button", "content", "searchInput", "clearButton"]
  static values = { name: String }

  connect() {
    if (this.hasItemsTarget) {
      this.restoreOrder()
      
      // Restore accordion state
      const facetId = this.element.id
      const isExpanded = sessionStorage.getItem(`${facetId}-expanded`) === 'true'
      if (isExpanded) {
        this.expand()
      }
    }
  }

  restoreOrder() {
    const facetId = this.element.id
    const orderKey = `${facetId}-order`
    let selectedOrder = JSON.parse(sessionStorage.getItem(orderKey) || '[]')
    
    const items = Array.from(this.itemTargets)
    const itemsContainer = this.itemsTarget
    
    // Separate checked and unchecked items
    const checkedItems = items.filter(item => item.querySelector('input[type="checkbox"]').checked)
    const uncheckedItems = items.filter(item => !item.querySelector('input[type="checkbox"]').checked)
    
    // Sort checked items based on stored order
    const sortedCheckedItems = checkedItems.sort((a, b) => {
      const valueA = a.dataset.value
      const valueB = b.dataset.value
      const indexA = selectedOrder.indexOf(valueA)
      const indexB = selectedOrder.indexOf(valueB)
      
      if (indexA === -1 && indexB === -1) return 0
      if (indexA === -1) return 1
      if (indexB === -1) return -1
      return indexA - indexB
    })
    
    // Update stored order with any new checked items
    selectedOrder = [
      ...selectedOrder.filter(value => checkedItems.some(item => item.dataset.value === value)),
      ...checkedItems
        .filter(item => !selectedOrder.includes(item.dataset.value))
        .map(item => item.dataset.value)
    ]
    sessionStorage.setItem(orderKey, JSON.stringify(selectedOrder))
    
    // Sort unchecked items alphabetically
    const sortedUncheckedItems = uncheckedItems.sort((a, b) => 
      a.dataset.value.toLowerCase().localeCompare(b.dataset.value.toLowerCase())
    )
    
    // Clear and reappend all items in the correct order
    while (itemsContainer.firstChild) {
      itemsContainer.removeChild(itemsContainer.firstChild)
    }
    
    // Append all items in the correct order
    [...sortedCheckedItems, ...sortedUncheckedItems].forEach(item => 
      itemsContainer.appendChild(item)
    )
  }

  submitForm(event) {
    event.preventDefault()
    const checkbox = event.target
    const facetId = this.element.id
    const orderKey = `${facetId}-order`
    
    if (checkbox.checked) {
      // Add new selection to the end of the order
      const selectedOrder = JSON.parse(sessionStorage.getItem(orderKey) || '[]')
      selectedOrder.push(checkbox.value)
      sessionStorage.setItem(orderKey, JSON.stringify(selectedOrder))
      
      this.appendToSelectedItems(checkbox)
    } else {
      // Remove from order when unchecked
      const selectedOrder = JSON.parse(sessionStorage.getItem(orderKey) || '[]')
      const updatedOrder = selectedOrder.filter(value => value !== checkbox.value)
      sessionStorage.setItem(orderKey, JSON.stringify(updatedOrder))
      
      this.moveToUnselected(checkbox)
    }
    
    // Store current expanded state before form submission
    sessionStorage.setItem(`${facetId}-expanded`, 'true')
    this.expand()
    
    setTimeout(() => {
      event.target.closest('form').requestSubmit()
    }, 0)
  }

  appendToSelectedItems(checkbox) {
    const item = checkbox.closest('[data-facet-target="item"]')
    const itemsContainer = this.itemsTarget
    
    // Get all checked items
    const checkedItems = Array.from(this.itemTargets).filter(i => 
      i.querySelector('input[type="checkbox"]').checked && i !== item
    )
    
    // Always append to the end of checked items
    if (checkedItems.length > 0) {
      checkedItems[checkedItems.length - 1].after(item)
    } else {
      itemsContainer.prepend(item)
    }
  }

  moveToUnselected(checkbox) {
    const item = checkbox.closest('[data-facet-target="item"]')
    const itemValue = item.dataset.value.toLowerCase()
    
    // Find all unselected items
    const unselectedItems = Array.from(this.itemTargets).filter(i => 
      !i.querySelector('input[type="checkbox"]').checked && i !== item
    )
    
    // Find the correct alphabetical position
    const insertPosition = unselectedItems.find(unselected => 
      unselected.dataset.value.toLowerCase() > itemValue
    )
    
    if (insertPosition) {
      insertPosition.before(item)
    } else if (unselectedItems.length > 0) {
      unselectedItems[unselectedItems.length - 1].after(item)
    } else {
      this.itemsTarget.appendChild(item)
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
    
    // Store accordion state
    const facetId = this.element.id
    sessionStorage.setItem(`${facetId}-expanded`, isCollapsed)
  }

  expand() {
    this.contentTarget.style.maxHeight = 'none'
    this.buttonTarget.querySelector('svg').classList.add('rotate-180')
  }

  collapse() {
    this.contentTarget.style.maxHeight = '0px'
    this.buttonTarget.querySelector('svg').classList.remove('rotate-180')
  }

  filter(event) {
    const searchTerm = event.target.value.toLowerCase()
    this.clearButtonTarget.style.display = searchTerm ? 'block' : 'none'
    
    this.itemTargets.forEach(item => {
      const value = item.dataset.value.toLowerCase()
      item.style.display = value.includes(searchTerm) ? 'flex' : 'none'
    })
  }

  clearSearch(event) {
    this.searchInputTarget.value = ''
    this.clearButtonTarget.style.display = 'none'
    this.itemTargets.forEach(item => {
      item.style.display = 'flex'
    })
  }
} 
