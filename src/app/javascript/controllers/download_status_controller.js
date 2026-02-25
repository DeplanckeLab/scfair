import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static PREPARING_MS = 4000
  static MAX_STATUS_MS = 10 * 60 * 1000

  connect() {
    this.activeLink = null
    this.phaseTimer = null
    this.resetTimer = null
  }

  disconnect() {
    this.clearPhaseTimer()
    this.clearResetTimer()
  }

  start(event) {
    const link = event.currentTarget
    if (!(link instanceof HTMLAnchorElement)) return

    if (this.activeLink && this.activeLink !== link) {
      this.reset(this.activeLink)
    }

    const label = link.dataset.downloadLabel || link.textContent.trim()
    this.activeLink = link
    link.dataset.originalHtml = link.innerHTML
    link.dataset.downloadLabel = label
    link.classList.add("opacity-70", "pointer-events-none")
    link.setAttribute("aria-busy", "true")
    this.renderStatus(link, "Preparing", label)

    this.clearPhaseTimer()
    this.clearResetTimer()
    this.phaseTimer = window.setTimeout(() => {
      this.renderStatus(link, "Download in progress", label)
    }, this.constructor.PREPARING_MS)
    this.resetTimer = window.setTimeout(() => this.reset(link), this.constructor.MAX_STATUS_MS)
  }

  reset(link = this.activeLink) {
    if (!link) return

    if (link.dataset.originalHtml) {
      link.innerHTML = link.dataset.originalHtml
      delete link.dataset.originalHtml
    }

    link.classList.remove("opacity-70", "pointer-events-none")
    link.removeAttribute("aria-busy")

    if (this.activeLink === link) {
      this.activeLink = null
    }

    this.clearPhaseTimer()
    this.clearResetTimer()
  }

  clearPhaseTimer() {
    if (!this.phaseTimer) return

    window.clearTimeout(this.phaseTimer)
    this.phaseTimer = null
  }

  clearResetTimer() {
    if (!this.resetTimer) return

    window.clearTimeout(this.resetTimer)
    this.resetTimer = null
  }

  renderStatus(link, statusText, label) {
    link.innerHTML = `${this.spinnerIcon()}<span>${statusText}: ${this.escapeHtml(label)}</span>`
  }

  spinnerIcon() {
    return `
      <svg xmlns="http://www.w3.org/2000/svg" class="w-3 h-3 animate-spin" viewBox="0 0 24 24" fill="none" aria-hidden="true">
        <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="3"></circle>
        <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8v3a5 5 0 00-5 5H4z"></path>
      </svg>
    `.trim()
  }

  escapeHtml(text) {
    return text
      .replaceAll("&", "&amp;")
      .replaceAll("<", "&lt;")
      .replaceAll(">", "&gt;")
      .replaceAll("\"", "&quot;")
      .replaceAll("'", "&#39;")
  }
}
