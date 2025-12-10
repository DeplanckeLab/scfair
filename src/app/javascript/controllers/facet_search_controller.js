import { Controller } from "@hotwired/stimulus"

// FacetSearchController handles facet search input with debouncing.
//
// @example HTML usage
//   <div data-controller="facet-search" data-facet-search-category-value="tissue">
//     <input type="text"
//            data-facet-search-target="input"
//            data-action="input->facet-search#search">
//     <button data-facet-search-target="clearButton"
//             data-action="click->facet-search#clear"
//             class="hidden">
//       Clear
//     </button>
//   </div>
//
export default class extends Controller {
  static targets = ["input", "clearButton"]

  static values = {
    category: String,
    debounceMs: { type: Number, default: 200 },
    minLength: { type: Number, default: 2 }
  }

  connect() {
    // Listen for clear events from parent panel controller
    this.element.addEventListener("facet-panel:search-cleared", this.#handleClearEvent.bind(this))
  }

  disconnect() {
    clearTimeout(this.searchTimeout)
  }

  search(event) {
    clearTimeout(this.searchTimeout)

    const searchValue = event.target.value.trim()
    this.#toggleClearButton(searchValue)

    if (!searchValue) {
      this.clear()
      return
    }

    if (searchValue.length < this.minLengthValue) return

    this.searchTimeout = setTimeout(() => {
      this.#updateFrameSrc(searchValue)
    }, this.debounceMsValue)
  }

  clear(event) {
    event?.preventDefault()
    event?.stopPropagation()

    if (this.hasInputTarget) {
      this.inputTarget.value = ""
    }

    this.#toggleClearButton("")
    this.#restoreDefaultContent()
  }

  // Private

  #handleClearEvent() {
    this.clear()
  }

  #toggleClearButton(searchValue) {
    if (!this.hasClearButtonTarget) return
    this.clearButtonTarget.classList.toggle("hidden", !searchValue)
  }

  #getContentFrame() {
    // Look for the content frame in the parent panel
    const panel = this.element.closest("[data-controller~='facet-panel']")
    return panel?.querySelector(`#facet_content_${this.categoryValue}`)
  }

  #updateFrameSrc(query) {
    const frame = this.#getContentFrame()
    if (!frame) return
    frame.src = `/facets/${this.categoryValue}/search?q=${encodeURIComponent(query)}`
  }

  #restoreDefaultContent() {
    const frame = this.#getContentFrame()
    if (!frame) return
    const currentParams = new URLSearchParams(window.location.search)
    frame.src = `/facets/${this.categoryValue}?${currentParams.toString()}`
  }
}
