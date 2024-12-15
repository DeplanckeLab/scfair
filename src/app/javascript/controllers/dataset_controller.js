import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["spinner", "container"]
  static values = {
    minimumLoadingDuration: { type: Number, default: 100 }
  }

  connect() {
    this.addTurboFrameListeners()
    this.loadingStartTime = 0
  }

  disconnect() {
    this.removeTurboFrameListeners()
  }

  addTurboFrameListeners() {
    this.frame = this.element.querySelector('turbo-frame#datasets');

    if (!this.frame) {
      console.warn('Turbo Frame with ID "datasets" not found within the controller\'s element.');
      return;
    }

    this.startLoading = this.startLoading.bind(this);
    this.stopLoading = this.stopLoading.bind(this);

    this.frame.addEventListener('turbo:before-fetch-request', this.startLoading);
    this.frame.addEventListener('turbo:before-fetch-response', this.stopLoading);
    this.frame.addEventListener('turbo:fetch-request-error', this.stopLoading);

    // console.log('Event listeners attached to frame:', this.frame);
  }

  removeTurboFrameListeners() {
    if (!this.frame) return;

    this.frame.removeEventListener('turbo:before-fetch-request', this.startLoading);
    this.frame.removeEventListener('turbo:before-fetch-response', this.stopLoading);
    this.frame.removeEventListener('turbo:fetch-request-error', this.stopLoading);
  }

  startLoading(event) {
    if (event.target !== this.frame) {
      return;
    }

    // console.log("startLoading called");

    clearTimeout(this.loadingTimeout);
    clearTimeout(this.hideTimeout);

    this.loadingStartTime = Date.now();

    // Show the spinner
    if (this.hasContainerTarget) {
      this.containerTarget.classList.remove('hidden');
    }
    if (this.hasSpinnerTarget) {
      this.spinnerTarget.classList.remove('hidden');
      this.spinnerTarget.classList.add('opacity-100');
    }
  }

  stopLoading(event) {
    if (event.target !== this.frame) {
      return;
    }

    // console.log("stopLoading called");

    clearTimeout(this.loadingTimeout);

    // Hide the spinner after ensuring minimum loading duration
    const elapsedTime = Date.now() - this.loadingStartTime;
    const remainingTime = Math.max(0, this.minimumLoadingDurationValue - elapsedTime);

    this.hideTimeout = setTimeout(() => {
      this.hideSpinner();
    }, remainingTime);
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