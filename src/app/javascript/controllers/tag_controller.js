import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    name: String,
    ontologyUrl: { type: String, default: null },
    bgColor: String,
    textColor: String
  }

  static targets = ["colorTag"]

  connect() {
    // Add click handler to modal backdrop
    const modal = document.getElementById("tag-modal")
    if (modal) {
      modal.addEventListener('click', this.handleBackdropClick.bind(this))
    }
  }

  disconnect() {
    // Remove click handler from modal backdrop
    const modal = document.getElementById("tag-modal")
    if (modal) {
      modal.removeEventListener('click', this.handleBackdropClick.bind(this))
    }
  }

  showModal(event) {
    event.preventDefault()
    event.stopPropagation()
    
    const modal = document.getElementById("tag-modal")
    if (modal) {
      modal.classList.remove('hidden')
    }
    
    const frame = document.getElementById("tag-modal-content")
    if (frame) {
      if (this.ontologyUrlValue) {
        // Show loading spinner
        frame.innerHTML = `
          <div class="flex items-center justify-center p-4">
            <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-gray-900"></div>
          </div>
        `
        
        fetch(this.ontologyUrlValue, {
          headers: {
            'Accept': 'text/vnd.turbo-stream.html'
          }
        })
        .then(response => response.text())
        .then(html => {
          frame.innerHTML = html
          // Wait for the next frame to ensure DOM is updated
          requestAnimationFrame(() => {
            this.applyTagColors()
          })
        })
      } else {
        // Show empty state
        frame.innerHTML = `
          <div class="sm:flex sm:items-start">
            <div class="mt-3 text-center sm:mt-0 sm:text-left w-full">
              <div class="flex items-center gap-3 mb-4">
                <div class="px-2 py-0.5 rounded-full text-xs ${this.bgColorValue} ${this.textColorValue}">
                  ${this.nameValue}
                </div>
              </div>
              <div>
                <p class="text-sm text-gray-500">No ontology information available for this tag.</p>
              </div>
            </div>
          </div>
        `
      }
    }
  }

  applyTagColors() {
    // Try to find the tag element in multiple ways
    const tagDiv = document.querySelector('#tag-modal-content [data-bg-color]')
    if (tagDiv) {
      // Remove any existing color classes first
      tagDiv.classList.remove(
        ...Array.from(tagDiv.classList).filter(cls => 
          cls.startsWith('bg-') || cls.startsWith('text-')
        )
      )
      // Add new color classes
      tagDiv.classList.add(this.bgColorValue, this.textColorValue)
    }
  }

  hideModal() {
    const modal = document.getElementById("tag-modal")
    if (modal) {
      modal.classList.add('hidden')
    }
  }

  stopPropagation(event) {
    event.stopPropagation()
  }

  handleBackdropClick(event) {
    const modalContent = document.querySelector('.relative.transform')
    if (modalContent && !modalContent.contains(event.target)) {
      this.hideModal()
    }
  }
}