import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.showSpinner = this.showSpinner.bind(this)
    this.hideSpinner = this.hideSpinner.bind(this)

    const searchForm = document.getElementById("search_form")
    if (searchForm) {
      searchForm.addEventListener("submit", this.showSpinner)
    }

    document.addEventListener("turbo:frame-load", this.hideSpinner)
    document.addEventListener("turbo:frame-render", this.hideSpinner)
  }

  disconnect() {
    const searchForm = document.getElementById("search_form")
    if (searchForm) {
      searchForm.removeEventListener("submit", this.showSpinner)
    }

    document.removeEventListener("turbo:frame-load", this.hideSpinner)
    document.removeEventListener("turbo:frame-render", this.hideSpinner)
  }

  showSpinner() {
    const spinner = document.getElementById("loading-spinner")
    if (spinner) spinner.style.display = "flex"
  }

  hideSpinner() {
    const spinner = document.getElementById("loading-spinner")
    if (spinner) spinner.style.display = "none"
  }
}