import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  open(event) {
    event.preventDefault()

    const url = event.currentTarget.getAttribute("href")
    const modal = document.getElementById("stats-check-modal")
    const frame = document.getElementById("stats-check-modal-content")
    if (!modal || !frame || !url) return

    modal.classList.remove("hidden")
    frame.innerHTML = `
      <div class="flex items-center justify-center p-8">
        <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-gray-900"></div>
      </div>
    `

    fetch(url, { headers: { Accept: "text/html" } })
      .then((response) => {
        if (!response.ok) throw new Error(`Failed to load failing datasets (${response.status})`)
        return response.text()
      })
      .then((html) => {
        frame.innerHTML = html
      })
      .catch((error) => {
        frame.innerHTML = `
          <div class="p-6">
            <p class="text-sm text-red-700">${error.message}</p>
          </div>
        `
      })
  }

  close() {
    const modal = document.getElementById("stats-check-modal")
    if (modal) modal.classList.add("hidden")
  }

  stopPropagation(event) {
    event.stopPropagation()
  }

  backdropClose(event) {
    if (event.target === event.currentTarget) this.close()
  }
}
