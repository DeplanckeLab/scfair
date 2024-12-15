import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    name: String,
    bgColor: String,
    textColor: String
  }

  static targets = ["colorTag", "spinner", "text", "tooltip"]

  connect() {
    const modal = document.getElementById("tag-modal")
    if (modal) {
      modal.addEventListener('click', this.handleBackdropClick.bind(this))
    }
    if (this.hasTextTarget && this.hasTooltipTarget) {
      this.checkTruncation()
    }
  }

  disconnect() {
    const modal = document.getElementById("tag-modal")
    if (modal) {
      modal.removeEventListener('click', this.handleBackdropClick.bind(this))
    }
  }

  showModal(event) {
    event.preventDefault()
    event.stopPropagation()

    const ontologyUrl = event.currentTarget.getAttribute('href')
    
    const modal = document.getElementById("tag-modal")
    if (modal) {
      modal.classList.remove('hidden')
    }
    
    const frame = document.getElementById("tag-modal-content")
    if (frame) {
      if (ontologyUrl && ontologyUrl != "#") {
        frame.innerHTML = `
          <div class="flex items-center justify-center p-4" data-tag-target="spinner">
            <div class="flex items-center">
              <svg class="animate-spin h-8 w-8 text-brand-dark" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
              </svg>
            </div>
          </div>
        `
        
        fetch(ontologyUrl, {
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
        frame.innerHTML = `
          <div class="sm:flex sm:items-start">
            <div class="mt-3 text-center sm:mt-0 sm:text-left w-full">
              <div class="flex items-center gap-3 mb-4">
                <div class="px-2 py-0.5 rounded-full text-xs ${this.bgColorValue || ''} ${this.textColorValue || ''}">
                  ${this.nameValue || ''}
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
    const tagDiv = document.querySelector('#tag-modal-content [data-bg-color]')
    if (tagDiv) {
      tagDiv.classList.remove(
        ...Array.from(tagDiv.classList).filter(cls => 
          cls.startsWith('bg-') || cls.startsWith('text-')
        )
      )
      if (this.bgColorValue) tagDiv.classList.add(this.bgColorValue)
      if (this.textColorValue) tagDiv.classList.add(this.textColorValue)
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

  checkTruncation() {
    const textElement = this.textTarget
    const isTextTruncated = textElement.scrollWidth > textElement.clientWidth

    if (!isTextTruncated) {
      this.tooltipTarget.classList.add('!hidden')
    }
  }
}