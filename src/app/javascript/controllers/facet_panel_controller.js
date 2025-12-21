import { Controller } from "@hotwired/stimulus"

// FacetPanelController handles the panel expand/collapse state,
// selection badges, and clear functionality.
//
// This is the "outer" controller for a facet panel, coordinating
// with nested tree/search/pagination controllers via events.
//
// @example HTML usage
//   <div data-controller="facet-panel"
//        data-facet-panel-category-value="tissue"
//        data-facet-panel-param-key-value="tissues">
//
export default class extends Controller {
  static targets = [
    "scrollableContent",
    "selectedBadge",
    "clearButton",
    "chevron",
    "searchContainer",
    "searchInput",
    "contentFrame"
  ]

  static values = {
    category: String,
    paramKey: String,
    expanded: { type: Boolean, default: false },
    expandedHeight: { type: String, default: "24rem" },
    collapsedHeight: { type: String, default: "0" }
  }

  connect() {
    this.form = document.getElementById("search_form")
    this.#loadSavedState()
    this.#updateSelectedCount()

    // Auto-expand if has selections
    if (this.#hasSelectedItems() && !this.expandedValue) {
      this.expandedValue = true
      this.expand(false)
    }

    // Listen for selection changes from nested controllers
    this.element.addEventListener("facet:selection-changed", this.#handleSelectionChanged.bind(this))
  }

  disconnect() {
    this.#saveState()
  }

  toggleExpand(event) {
    event?.preventDefault()
    event?.stopPropagation()

    this.expandedValue = !this.expandedValue
    this.expandedValue ? this.expand() : this.collapse()
    this.#saveState()
  }

  expand(autoFocus = true) {
    this.#lazyLoadContentIfNeeded()
    this.scrollableContentTarget.style.maxHeight = this.expandedHeightValue
    this.chevronTarget.style.transform = "rotate(90deg)"

    if (this.hasSearchContainerTarget) {
      this.searchContainerTarget.classList.remove("hidden")
      if (autoFocus && this.hasSearchInputTarget) {
        setTimeout(() => this.searchInputTarget.focus(), 200)
      }
    }
  }

  collapse() {
    this.scrollableContentTarget.style.maxHeight = this.collapsedHeightValue
    this.chevronTarget.style.transform = "rotate(0deg)"
    this.searchContainerTarget?.classList.add("hidden")
  }

  clearCategory(event) {
    event.preventDefault()
    event.stopPropagation()

    // Uncheck all checkboxes
    this.element.querySelectorAll("input[type='checkbox']:checked").forEach(cb => {
      cb.checked = false
    })

    // Clear search if present
    if (this.hasSearchInputTarget) {
      this.searchInputTarget.value = ""
      this.dispatch("search-cleared")
    }

    // Clear sessionStorage
    sessionStorage.setItem(`selections_${this.#getParamKey()}`, JSON.stringify([]))

    // Navigate to URL without this facet's params
    const urlParams = new URLSearchParams(window.location.search)
    urlParams.delete(`${this.#getParamKey()}[]`)

    const newUrl = urlParams.toString()
      ? `${window.location.pathname}?${urlParams.toString()}`
      : window.location.pathname

    Turbo.visit(newUrl)
  }

  // Handle selection changes from tree controller
  handleSelection(event) {
    this.#updateSelectedCount()
    this.#saveState()
    this.form?.requestSubmit()
  }

  // Private

  #handleSelectionChanged() {
    this.#updateSelectedCount()
    this.#saveState()
    this.form?.requestSubmit()
  }

  #hasSelectedItems() {
    return this.element.querySelectorAll("input[type='checkbox']:checked").length > 0
  }

  #lazyLoadContentIfNeeded() {
    if (!this.hasContentFrameTarget) return

    const frame = this.contentFrameTarget
    if (frame.dataset.loaded === "true" || frame.hasAttribute("src")) return

    const currentParams = new URLSearchParams(window.location.search)
    frame.setAttribute("src", `/facets/${this.categoryValue}?${currentParams.toString()}`)
    frame.dataset.loaded = "true"
  }

  #updateSelectedCount() {
    let count = this.element.querySelectorAll("input[type='checkbox']:checked").length

    // If content not loaded yet, get count from URL
    if (!this.#contentLoaded()) {
      const urlParams = new URLSearchParams(window.location.search)
      count = urlParams.getAll(`${this.#getParamKey()}[]`).length
    }

    if (count > 0) {
      if (this.hasSelectedBadgeTarget) {
        this.selectedBadgeTarget.textContent = count
        this.selectedBadgeTarget.classList.remove("hidden")
      }
      this.clearButtonTarget?.classList.remove("hidden")
    } else {
      this.selectedBadgeTarget?.classList.add("hidden")
      this.clearButtonTarget?.classList.add("hidden")
    }

    // Update sessionStorage
    this.#updateGlobalSelections()
  }

  #contentLoaded() {
    if (!this.hasContentFrameTarget) return true
    return this.contentFrameTarget.dataset.loaded === "true" &&
           this.element.querySelector("input[type='checkbox']") !== null
  }

  #updateGlobalSelections() {
    let selectedIds = Array.from(
      this.element.querySelectorAll("input[type='checkbox']:checked")
    ).map(cb => cb.value)

    if (!this.#contentLoaded() && selectedIds.length === 0) {
      const urlParams = new URLSearchParams(window.location.search)
      selectedIds = urlParams.getAll(`${this.#getParamKey()}[]`)
    }

    sessionStorage.setItem(`selections_${this.#getParamKey()}`, JSON.stringify(selectedIds))
  }

  #getParamKey() {
    // Use data attribute if provided, otherwise fall back to category value
    return this.paramKeyValue || this.categoryValue
  }

  #saveState() {
    const expandedNodes = []
    this.element.querySelectorAll("[data-facet-tree-target='childrenContainer']:not(.hidden)").forEach(container => {
      if (container.dataset.parentId) {
        expandedNodes.push(container.dataset.parentId)
      }
    })

    const state = {
      expanded: this.expandedValue,
      scrollTop: this.scrollableContentTarget.scrollTop,
      searchTerm: this.searchInputTarget?.value || "",
      expandedNodes
    }

    sessionStorage.setItem(`facet-${this.categoryValue}`, JSON.stringify(state))
  }

  #loadSavedState() {
    const saved = sessionStorage.getItem(`facet-${this.categoryValue}`)
    if (!saved) return

    try {
      const state = JSON.parse(saved)

      if (state.expanded) {
        this.expandedValue = true
        this.expand(false)
      }

      if (state.scrollTop) {
        this.scrollableContentTarget.scrollTop = state.scrollTop
      }

      // Tree node expansion is handled by facet-tree controller
      if (state.expandedNodes?.length > 0) {
        this.dispatch("restore-expanded-nodes", { detail: { nodeIds: state.expandedNodes } })
      }
    } catch {
      // Ignore invalid saved state
    }
  }
}
