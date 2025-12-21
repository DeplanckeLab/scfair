import { Controller } from "@hotwired/stimulus"

// FacetPaginationController handles infinite scroll pagination using IntersectionObserver.
//
// @example HTML usage
//   <div data-controller="facet-pagination"
//        data-facet-pagination-root-value="#scrollable-content">
//     <div data-facet-pagination-target="paginationLink">
//       <a href="/facets/tissue?offset=30" class="pagination-link">Load more</a>
//       <div class="pagination-skeleton hidden">Loading...</div>
//     </div>
//   </div>
//
export default class extends Controller {
  static targets = ["paginationLink"]

  static values = {
    root: { type: String, default: "" },
    rootMargin: { type: String, default: "100px" },
    autoLoad: { type: Boolean, default: true }
  }

  connect() {
    if (this.autoLoadValue) {
      this.#setupObserver()
    }
  }

  disconnect() {
    this.#observer?.disconnect()
  }

  showLoading(event) {
    const container = event.target.closest("[data-facet-pagination-target='paginationLink']")
    if (container) {
      this.#showSkeleton(container)
    }
  }

  // Callback when pagination link enters viewport
  paginationLinkTargetConnected(link) {
    if (this.autoLoadValue && this.#observer) {
      this.#observer.observe(link)
    }
  }

  paginationLinkTargetDisconnected(link) {
    this.#observer?.unobserve(link)
  }

  // Private

  #observer = null

  #setupObserver() {
    this.#observer?.disconnect()

    const root = this.rootValue
      ? document.querySelector(this.rootValue)
      : this.element.closest("[data-facet-panel-target='scrollableContent']")

    this.#observer = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting && entry.target.matches("[data-facet-pagination-target='paginationLink']")) {
            const link = entry.target.querySelector(".pagination-link")
            if (link) {
              this.#showSkeleton(entry.target)
              link.click()
            }
          }
        })
      },
      {
        root: root,
        rootMargin: this.rootMarginValue,
        threshold: 0
      }
    )

    // Observe existing pagination links
    this.paginationLinkTargets.forEach(link => {
      this.#observer.observe(link)
    })
  }

  #showSkeleton(container) {
    const link = container.querySelector(".pagination-link")
    const skeleton = container.querySelector(".pagination-skeleton")

    if (link) link.classList.add("hidden")
    if (skeleton) skeleton.classList.remove("hidden")
  }
}
