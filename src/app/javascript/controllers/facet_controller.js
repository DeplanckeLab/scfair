import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["items", "item", "button", "content", "searchInput", "clearButton", "hiddenCounter", "hiddenCount"]
  static values = { 
    name: String, 
    showingAll: Boolean,
    currentSearch: String,
    facetId: String 
  }

  connect() {
    this.facetIdValue = this.element.id
    this.form = this.element.closest('form')
    
    if (this.hasItemsTarget) {
      this.showingAllValue = false
      this.updateSelectedCount()
      this.restoreOrder()
      
      // Restore search state if exists and if we have search input
      if (this.hasSearchInputTarget) {
        const savedSearch = sessionStorage.getItem(`${this.facetIdValue}-search`)
        if (savedSearch) {
          this.searchInputTarget.value = savedSearch
          this.currentSearchValue = savedSearch
          if (this.hasClearButtonTarget) {
            this.clearButtonTarget.style.display = 'block'
          }
          this.applySearch(savedSearch)
        } else {
          if (this.hasClearButtonTarget) {
            this.clearButtonTarget.style.display = 'none'
          }
          this.limitUnselectedItems()
        }
      } else {
        this.limitUnselectedItems()
      }
      
      // Restore accordion state
      const isExpanded = sessionStorage.getItem(`${this.facetIdValue}-expanded`) === 'true'
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
    
    // Sort unchecked items alphabetically
    const sortedUncheckedItems = uncheckedItems.sort((a, b) => 
      a.dataset.value.toLowerCase().localeCompare(b.dataset.value.toLowerCase())
    )
    
    // Clear and reappend all items
    while (itemsContainer.firstChild) {
      itemsContainer.removeChild(itemsContainer.firstChild)
    }
    
    // Append all items in order
    sortedCheckedItems.forEach(item => itemsContainer.appendChild(item))
    sortedUncheckedItems.forEach(item => itemsContainer.appendChild(item))
    
    // Update stored order
    selectedOrder = [
      ...selectedOrder.filter(value => checkedItems.some(item => item.dataset.value === value)),
      ...checkedItems
        .filter(item => !selectedOrder.includes(item.dataset.value))
        .map(item => item.dataset.value)
    ]
    sessionStorage.setItem(orderKey, JSON.stringify(selectedOrder))
  }

  toggleShowAll() {
    this.showingAllValue = !this.showingAllValue
    
    if (this.showingAllValue) {
      // Show all items
      this.getUncheckedItems().forEach(item => {
        item.style.display = 'flex'
      })
      this.hiddenCounterTarget.textContent = 'Show less'
    } else {
      // Show only first 10
      this.limitUnselectedItems()
    }
  }

  limitUnselectedItems() {
    if (this.showingAllValue) return

    const uncheckedItems = this.getUncheckedItems()
    
    uncheckedItems.forEach((item, index) => {
      item.style.display = index < 10 ? 'flex' : 'none'
    })
    
    // Update hidden counter
    const hiddenCount = Math.max(0, uncheckedItems.length - 10)
    this.updateHiddenCounter(hiddenCount)
  }

  updateHiddenCounter(count) {
    if (this.hasHiddenCounterTarget) {
      if (count > 0) {
        if (this.showingAllValue) {
          this.hiddenCounterTarget.textContent = 'Show less'
        } else {
          this.hiddenCounterTarget.textContent = `Show ${count} more options`
        }
        this.hiddenCounterTarget.classList.remove('hidden')
      } else {
        this.hiddenCounterTarget.classList.add('hidden')
      }
    }
  }

  filter(event) {
    const searchTerm = event.target.value.toLowerCase()
    if (this.hasClearButtonTarget) {
      this.clearButtonTarget.style.display = searchTerm ? 'block' : 'none'
    }
    
    // Save search state
    const facetId = this.element.id
    sessionStorage.setItem(`${facetId}-search`, searchTerm)
    this.currentSearchValue = searchTerm
    
    this.applySearch(searchTerm)
  }

  applySearch(searchTerm) {
    let hiddenCount = 0
    
    this.itemTargets.forEach(item => {
      const value = item.dataset.value.toLowerCase()
      const isChecked = item.querySelector('input[type="checkbox"]').checked
      
      // Always show checked items, filter unchecked ones
      if (isChecked) {
        item.style.display = 'flex'
      } else {
        const shouldShow = value.includes(searchTerm)
        item.style.display = shouldShow ? 'flex' : 'none'
        if (!shouldShow) hiddenCount++
      }
    })
    
    // Hide the show more/less button during search
    this.hiddenCounterTarget.classList.add('hidden')
  }

  getUncheckedItems() {
    return this.itemTargets.filter(item => 
      !item.querySelector('input[type="checkbox"]').checked
    )
  }

  clearSearch(event) {
    if (this.hasSearchInputTarget) {
      this.searchInputTarget.value = ''
    }
    if (this.hasClearButtonTarget) {
      this.clearButtonTarget.style.display = 'none'
    }
    
    // Clear saved search state
    const facetId = this.element.id
    sessionStorage.removeItem(`${facetId}-search`)
    this.currentSearchValue = ''
    
    // Reset showing all state
    this.showingAllValue = false
    
    // Restore limited view
    this.limitUnselectedItems()
  }

  submitForm(event) {
    event.preventDefault()
    const checkbox = event.target
    if (checkbox.checked) {
      this.appendToSelectedItems(checkbox)
    } else {
      this.moveToUnselected(checkbox)
    }
    this.updateSelectedCount()

    if (this.form) {
      this.form.setAttribute('data-turbo-frame', 'datasets')
      this.form.requestSubmit()
    }
  }

  appendToSelectedItems(checkbox) {
    const item = checkbox.closest('[data-facet-target="item"]')
    const itemsContainer = this.itemsTarget

    // Remove item from its current position
    itemsContainer.removeChild(item)

    // Insert item at the top
    itemsContainer.insertBefore(item, itemsContainer.firstChild)
  }

  moveToUnselected(checkbox) {
    const item = checkbox.closest('[data-facet-target="item"]')
    const itemValue = item.dataset.value.toLowerCase()

    // Remove item from its current position
    this.itemsTarget.removeChild(item)

    // Find the correct position to insert alphabetically among unchecked items
    const uncheckedItems = this.itemTargets.filter(i => 
      !i.querySelector('input[type="checkbox"]').checked
    )

    const insertBeforeItem = uncheckedItems.find(unselected => 
      unselected.dataset.value.toLowerCase() > itemValue
    )

    if (insertBeforeItem) {
      this.itemsTarget.insertBefore(item, insertBeforeItem)
    } else {
      this.itemsTarget.appendChild(item)
    }
  }

  updateSelectedCount() {
    const checkedCheckboxes = this.itemTargets
      .map(item => item.querySelector('input[type="checkbox"]'))
      .filter(checkbox => checkbox.checked)

    const selectedCount = checkedCheckboxes.length

    // Update the count next to the category name
    const selectedCountSpan = this.buttonTarget.querySelector('.selected-count')
    if (selectedCount > 0) {
      selectedCountSpan.textContent = `${selectedCount} selected`
      selectedCountSpan.classList.remove('hidden')
    } else {
      selectedCountSpan.textContent = ''
      selectedCountSpan.classList.add('hidden')
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

  clearAllSelected(event) {
    event.preventDefault()
    event.stopPropagation() // Prevent accordion toggle

    // Get all checked checkboxes
    const checkedCheckboxes = this.itemTargets
      .map(item => item.querySelector('input[type="checkbox"]'))
      .filter(checkbox => checkbox.checked)

    // Uncheck all selected checkboxes
    checkedCheckboxes.forEach(checkbox => {
      checkbox.checked = false
    })

    // Update the selection order in sessionStorage
    const facetId = this.element.id
    const orderKey = `${facetId}-order`
    sessionStorage.setItem(orderKey, JSON.stringify([]))

    // Submit the form after unchecking
    setTimeout(() => {
      this.element.closest('form').requestSubmit()
    }, 0)
  }
} 
