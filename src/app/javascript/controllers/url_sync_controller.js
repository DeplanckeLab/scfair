import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

// Syncs form state with browser URL for faceted search
export default class extends Controller {
  connect() {
    // Intercept form submission to prevent Turbo Drive visit
    this.element.addEventListener('submit', this.handleSubmit.bind(this))
  }

  disconnect() {
    this.element.removeEventListener('submit', this.handleSubmit.bind(this))
  }

  async handleSubmit(event) {
    event.preventDefault()

    // Save currently focused element to restore after update
    const activeElement = document.activeElement
    const focusedId = activeElement?.id
    const focusedTagName = activeElement?.tagName

    // Build params using sessionStorage as source of truth for facet selections
    const params = new URLSearchParams()

    // Get form data for non-facet params (search, sort, page, etc.)
    const formData = new FormData(this.element)

    // Add non-array params from form (search, sort, page, etc.)
    for (const [key, value] of formData) {
      if (key === 'format') continue
      if (value === '') continue
      // Skip array params (facet filters) - we'll get those from sessionStorage
      if (!key.endsWith('[]')) {
        params.set(key, value)
      }
    }

    // Add facet selections from sessionStorage (updated by facet_enhanced controllers)
    // This ensures we have complete selection state even for lazy-loaded frames
    const facetCategories = [
      'organisms', 'tissues', 'developmental_stages', 'diseases', 'sexes', 'technologies',
      'cell_types', 'suspension_types', 'source'
    ]

    facetCategories.forEach(category => {
      const storageKey = `selections_${category}`
      const stored = sessionStorage.getItem(storageKey)

      if (stored) {
        try {
          const selectedIds = JSON.parse(stored)
          selectedIds.forEach(id => {
            params.append(`${category}[]`, id)
          })
        } catch (e) {
          console.error(`Failed to parse selections for ${category}:`, e)
        }
      }
    })

    // Build the fetch URL with turbo_stream format
    params.set('format', 'turbo_stream')
    const fetchUrl = `${this.element.action}?${params.toString()}`

    try {
      // Fetch the turbo_stream response
      const response = await fetch(fetchUrl, {
        headers: {
          'Accept': 'text/vnd.turbo-stream.html'
        }
      })

      if (response.ok) {
        const html = await response.text()
        // Let Turbo process the stream response
        Turbo.renderStreamMessage(html)

        // Update URL (without format parameter)
        const urlParams = new URLSearchParams()
        for (const [key, value] of params) {
          if (key === 'format') continue
          urlParams.append(key, value)
        }
        const newUrl = `${window.location.pathname}?${urlParams.toString()}`
        window.history.pushState({}, '', newUrl)

        // Restore focus to the element that triggered the update
        if (focusedId && focusedTagName === 'INPUT') {
          // Use requestAnimationFrame to ensure DOM is fully updated
          requestAnimationFrame(() => {
            const elementToFocus = document.getElementById(focusedId)
            if (elementToFocus) {
              elementToFocus.focus()
            }
          })
        }
      }
    } catch (error) {
      console.error('Form submission failed:', error)
    }
  }
}
