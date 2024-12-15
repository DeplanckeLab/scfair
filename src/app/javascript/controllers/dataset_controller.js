import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

export default class extends Controller {
  static targets = ["content", "summary", "spinner", "container", "tagModal"]
  static values = {
    minimumLoadingDuration: { type: Number, default: 200 },
    loadingDelay: { type: Number, default: 200 },
    expanded: { type: Boolean, default: false }
  }

  connect() {
    this.addTurboFrameListeners()
    this.loadingStartTime = 0

    // Set initial hover class based on expanded state
    if (!this.expandedValue) {
      this.containerTarget.classList.add('hover:bg-gray-50')
    }
  }

  disconnect() {
    this.removeTurboFrameListeners()
  }

  // Dataset expansion handling
  toggle() {
    this.expandedValue = !this.expandedValue
    
    // Toggle content visibility
    this.contentTarget.classList.toggle('hidden')
    this.summaryTarget.classList.toggle('hidden')
    
    // Toggle hover classes based on expanded state
    if (this.expandedValue) {
      this.containerTarget.classList.remove('hover:bg-gray-50')
    } else {
      this.containerTarget.classList.add('hover:bg-gray-50')
    }
  }

  // Tag modal handling
  showTagModal(event) {
    event.stopPropagation()
    
    const tag = event.currentTarget
    const tagName = tag.dataset.datasetTagName
    const bgColor = tag.dataset.datasetBgColor
    const textColor = tag.dataset.datasetTextColor
    const url = tag.dataset.datasetOntologyUrl

    // First show the modal with the tag
    this.tagModalTarget.classList.remove('hidden')
    
    // Then load ontology data if available
    if (url) {
      Turbo.visit(url, { frame: "modal_content" })
    }
  }

  hideTagModal() {
    this.tagModalTarget.classList.add('hidden')
  }

  // Loading state handling
  stopPropagation(event) {
    event.stopPropagation()
  }

  addTurboFrameListeners() {
    const frame = this.element.closest('turbo-frame')
    if (!frame) return

    this.startLoading = this.startLoading.bind(this)
    this.stopLoading = this.stopLoading.bind(this)

    frame.addEventListener('turbo:before-fetch-request', this.startLoading)
    frame.addEventListener('turbo:before-fetch-response', this.stopLoading)
    frame.addEventListener('turbo:fetch-request-error', this.stopLoading)
  }

  removeTurboFrameListeners() {
    const frame = this.element.closest('turbo-frame')
    if (!frame) return

    frame.removeEventListener('turbo:before-fetch-request', this.startLoading)
    frame.removeEventListener('turbo:before-fetch-response', this.stopLoading)
    frame.removeEventListener('turbo:fetch-request-error', this.stopLoading)
  }

  startLoading() {
    console.log("startLoading called");
    console.log("hasSpinnerTarget:", this.hasSpinnerTarget);
    console.log("hasContainerTarget:", this.hasContainerTarget);
    
    clearTimeout(this.loadingTimeout);
    clearTimeout(this.hideTimeout);
    
    this.loadingStartTime = Date.now();
    
    this.loadingTimeout = setTimeout(() => {
        console.log("Loading timeout triggered");
        if (this.hasContainerTarget) {
            console.log("Showing container");
            this.containerTarget.classList.remove('hidden');
        }
        if (this.hasSpinnerTarget) {
            console.log("Showing spinner");
            this.spinnerTarget.classList.remove('hidden');
            this.spinnerTarget.classList.add('opacity-100');
        }
    }, this.loadingDelayValue);
  }

  stopLoading() {
    clearTimeout(this.loadingTimeout)
    
    // Calculate how long the loader has been visible
    const elapsedTime = Date.now() - this.loadingStartTime
    const remainingTime = Math.max(0, this.minimumLoadingDurationValue - elapsedTime)
    
    // Check if spinner target exists and is visible
    if (this.hasSpinnerTarget && !this.spinnerTarget.classList.contains('hidden')) {
      this.hideTimeout = setTimeout(() => {
        this.hideSpinner()
      }, remainingTime)
    } else {
      // If loader wasn't shown yet, cancel it
      clearTimeout(this.loadingTimeout)
    }
  }

  hideSpinner() {
    if (this.hasSpinnerTarget) {
        this.spinnerTarget.classList.remove('opacity-100');
        this.spinnerTarget.classList.add('opacity-0');
        
        setTimeout(() => {
            this.spinnerTarget.classList.add('hidden');
            this.spinnerTarget.classList.remove('opacity-0');
            if (this.hasContainerTarget) {
                this.containerTarget.classList.add('hidden');
            }
        }, 150);
    }
  }
} 