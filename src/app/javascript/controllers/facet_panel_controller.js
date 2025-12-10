import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "searchInput",
    "searchContainer",
    "searchResults",
    "scrollableContent",
    "selectedBadge",
    "clearButton",
    "chevron",
    "treeNode",
    "nodeLabel",
    "nodeChevron",
    "childrenContainer",
    "clearSearchButton",
    "contentFrame",
    "loadMoreTrigger",
    "loadingIndicator",
    "paginationData"
  ]

  static values = {
    category: String,
    expanded: { type: Boolean, default: false },
    expandedHeight: { type: String, default: "24rem" },
    collapsedHeight: { type: String, default: "0" },
    offset: { type: Number, default: 0 },
    limit: { type: Number, default: 30 },
    hasMore: { type: Boolean, default: true },
    loading: { type: Boolean, default: false }
  }

  connect() {
    this.form = document.getElementById("search_form")
    this.#updateGlobalSelections()
    this.#loadSavedState()
    this.#updateSelectedCount()

    if (this.#hasSelectedItems() && !this.expandedValue) {
      this.expandedValue = true
      this.expand(false)
    }

    this.#boundFrameLoadHandler = this.#handleFrameLoad.bind(this)
    document.addEventListener("turbo:frame-load", this.#boundFrameLoadHandler)
    setTimeout(() => this.#setupInfiniteScroll(), 100)
  }

  disconnect() {
    this.#saveState()
    document.removeEventListener("turbo:frame-load", this.#boundFrameLoadHandler)
    this.#intersectionObserver?.disconnect()
  }

  toggleExpand(event) {
    event?.preventDefault()
    event?.stopPropagation()

    this.expandedValue = !this.expandedValue

    if (this.expandedValue) {
      this.expand()
    } else {
      this.collapse()
    }

    this.#saveState()
  }

  expand(autoFocus = true) {
    this.#lazyLoadContentIfNeeded()
    this.scrollableContentTarget.style.maxHeight = this.expandedHeightValue
    this.chevronTarget.style.transform = "rotate(90deg)"

    if (this.hasSearchContainerTarget) {
      this.searchContainerTarget.classList.remove("hidden")
      if (autoFocus) {
        setTimeout(() => this.searchInputTarget?.focus(), 200)
      }
    }
  }

  collapse() {
    this.scrollableContentTarget.style.maxHeight = this.collapsedHeightValue
    this.chevronTarget.style.transform = "rotate(0deg)"
    this.searchContainerTarget?.classList.add("hidden")
  }

  handleSelection(event) {
    const checkbox = event.target

    if (checkbox.checked) {
      this.#cascadeSelection(checkbox)
    } else {
      this.#clearCascadedMarkers(checkbox)
    }

    this.#updateSelectedCount()
    this.#saveState()
    this.form?.requestSubmit()
  }

  clearCategory(event) {
    event.preventDefault()
    event.stopPropagation()

    this.element.querySelectorAll("input[type='checkbox']:checked").forEach(cb => {
      cb.checked = false
    })

    if (this.hasSearchInputTarget) {
      this.searchInputTarget.value = ""
      this.clearSearch()
    }

    const paramKey = this.#getParamKey()
    sessionStorage.setItem(`selections_${paramKey}`, JSON.stringify([]))

    const urlParams = new URLSearchParams(window.location.search)
    urlParams.delete(`${paramKey}[]`)

    const newUrl = urlParams.toString()
      ? `${window.location.pathname}?${urlParams.toString()}`
      : window.location.pathname

    Turbo.visit(newUrl)
  }

  toggleNode(event) {
    event.preventDefault()
    event.stopPropagation()

    const button = event.currentTarget
    const nodeId = button.dataset.nodeId
    const childContainer = this.element.querySelector(`[data-parent-id="${nodeId}"]`)

    if (!childContainer) return

    const isHidden = childContainer.classList.contains("hidden")
    const chevron = button.querySelector("[data-facet-panel-target='nodeChevron']")

    if (isHidden) {
      childContainer.classList.remove("hidden")
      if (chevron) chevron.style.transform = "rotate(90deg)"

      const frame = childContainer.querySelector("turbo-frame")
      if (frame?.src && !frame.querySelector(".tree-node")) {
        frame.setAttribute("loading", "eager")
        const currentSrc = frame.src
        frame.src = ""
        requestAnimationFrame(() => { frame.src = currentSrc })
      }
    } else {
      childContainer.classList.add("hidden")
      if (chevron) chevron.style.transform = "rotate(0deg)"
    }

    this.#saveState()
  }

  searchInput(event) {
    clearTimeout(this.searchTimeout)

    const searchValue = event.target.value.trim()
    this.#toggleClearButton(searchValue)

    if (!searchValue) {
      this.clearSearch()
      return
    }

    if (searchValue.length < 2) return

    this.searchTimeout = setTimeout(() => this.#updateFrameSrc(searchValue), 200)
  }

  clearSearch(event) {
    event?.preventDefault()
    event?.stopPropagation()

    if (this.hasSearchInputTarget) {
      this.searchInputTarget.value = ""
    }

    this.#toggleClearButton("")

    if (this.hasContentFrameTarget) {
      const currentParams = new URLSearchParams(window.location.search)
      this.contentFrameTarget.src = `/facets/${this.categoryValue}?${currentParams.toString()}`
    }
  }

  // Private

  #handleFrameLoad(event) {
    const frame = event.target
    if (!this.element.contains(frame)) return

    this.#updateSelectedCount()

    const isRootContentFrame = frame.id?.startsWith(`facet_content_${this.categoryValue}`)
    if (isRootContentFrame && this.hasPaginationDataTarget) {
      this.hasMoreValue = this.paginationDataTarget.dataset.hasMore === "true"
      this.offsetValue = parseInt(this.paginationDataTarget.dataset.offset, 10) || 0
      setTimeout(() => this.#setupInfiniteScroll(), 100)
    }
  }

  #hasSelectedItems() {
    return this.element.querySelectorAll("input[type='checkbox']:checked").length > 0
  }

  #lazyLoadContentIfNeeded() {
    if (!this.hasContentFrameTarget) return

    const frame = this.contentFrameTarget
    if (frame.dataset.loaded === "true" || frame.hasAttribute("src")) return

    const currentParams = new URLSearchParams(window.location.search)
    frame.setAttribute("src", `/facets/${this.categoryValue}?${currentParams.toString()}`)
    frame.dataset.loaded = "true"
  }

  #cascadeSelection(checkbox) {
    const treeNode = checkbox.closest("[data-facet-panel-target='treeNode']")
    const nodeId = treeNode?.dataset.nodeId
    if (!nodeId) return

    const childrenContainer = this.element.querySelector(`[data-parent-id="${nodeId}"]`)
    childrenContainer?.querySelectorAll("input[type='checkbox']").forEach(cb => {
      if (!cb.checked) {
        cb.checked = true
        cb.dataset.originalName = cb.name
        cb.removeAttribute("name")
      }
    })
  }

  #clearCascadedMarkers(checkbox) {
    const treeNode = checkbox.closest("[data-facet-panel-target='treeNode']")
    const nodeId = treeNode?.dataset.nodeId
    if (!nodeId) return

    const childrenContainer = this.element.querySelector(`[data-parent-id="${nodeId}"]`)
    childrenContainer?.querySelectorAll("input[type='checkbox'][data-original-name]").forEach(cb => {
      cb.checked = false
      cb.name = cb.dataset.originalName
      delete cb.dataset.originalName
    })
  }

  #updateSelectedCount() {
    let count = this.element.querySelectorAll("input[type='checkbox']:checked").length

    if (!this.#contentLoaded()) {
      const paramKey = this.#getParamKey()
      const urlParams = new URLSearchParams(window.location.search)
      count = urlParams.getAll(`${paramKey}[]`).length
    }

    if (count > 0) {
      if (this.hasSelectedBadgeTarget) {
        this.selectedBadgeTarget.textContent = count
        this.selectedBadgeTarget.classList.remove("hidden")
      }
      this.clearButtonTarget?.classList.remove("hidden")
    } else {
      this.selectedBadgeTarget?.classList.add("hidden")
      this.clearButtonTarget?.classList.add("hidden")
    }

    this.#updateGlobalSelections()
  }

  #contentLoaded() {
    if (!this.hasContentFrameTarget) return true
    return this.contentFrameTarget.dataset.loaded === "true" &&
           this.element.querySelector("input[type='checkbox']") !== null
  }

  #updateGlobalSelections() {
    let selectedIds = Array.from(
      this.element.querySelectorAll("input[type='checkbox']:checked")
    ).map(cb => cb.value)

    if (!this.#contentLoaded() && selectedIds.length === 0) {
      const paramKey = this.#getParamKey()
      const urlParams = new URLSearchParams(window.location.search)
      selectedIds = urlParams.getAll(`${paramKey}[]`)
    }

    sessionStorage.setItem(`selections_${this.#getParamKey()}`, JSON.stringify(selectedIds))
  }

  #getParamKey() {
    const pluralMap = {
      organism: "organisms",
      tissue: "tissues",
      developmental_stage: "developmental_stages",
      disease: "diseases",
      sex: "sexes",
      technology: "technologies"
    }
    return pluralMap[this.categoryValue] || this.categoryValue
  }

  #toggleClearButton(searchValue) {
    if (!this.hasClearSearchButtonTarget) return
    this.clearSearchButtonTarget.classList.toggle("hidden", !searchValue)
  }

  #updateFrameSrc(query) {
    if (!this.hasContentFrameTarget) return
    this.contentFrameTarget.src = `/facets/${this.categoryValue}/search?q=${encodeURIComponent(query)}`
  }

  #saveState() {
    const expandedNodes = []
    this.element.querySelectorAll("[data-facet-panel-target='childrenContainer']:not(.hidden)").forEach(container => {
      if (container.dataset.parentId) {
        expandedNodes.push(container.dataset.parentId)
      }
    })

    const state = {
      expanded: this.expandedValue,
      scrollTop: this.scrollableContentTarget.scrollTop,
      searchTerm: this.searchInputTarget?.value || "",
      expandedNodes
    }

    sessionStorage.setItem(`facet-${this.categoryValue}`, JSON.stringify(state))
  }

  #loadSavedState() {
    const saved = sessionStorage.getItem(`facet-${this.categoryValue}`)
    if (!saved) return

    try {
      const state = JSON.parse(saved)

      if (state.expanded) {
        this.expandedValue = true
        this.expand(false)
      }

      if (state.scrollTop) {
        this.scrollableContentTarget.scrollTop = state.scrollTop
      }

      if (state.expandedNodes?.length > 0) {
        requestAnimationFrame(() => {
          state.expandedNodes.forEach(nodeId => this.#expandNodeById(nodeId))
        })
      }
    } catch {
      // Ignore invalid saved state
    }
  }

  #expandNodeById(nodeId) {
    const childContainer = this.element.querySelector(`[data-parent-id="${nodeId}"]`)
    if (!childContainer || !childContainer.classList.contains("hidden")) return

    const button = this.element.querySelector(`button[data-node-id="${nodeId}"]`)
    if (!button) return

    const chevron = button.querySelector("[data-facet-panel-target='nodeChevron']")
    const frame = childContainer.querySelector("turbo-frame")

    childContainer.classList.remove("hidden")
    if (chevron) chevron.style.transform = "rotate(90deg)"

    if (frame?.src && !frame.querySelector(".tree-node")) {
      frame.setAttribute("loading", "eager")
      const currentSrc = frame.src
      frame.src = ""
      requestAnimationFrame(() => { frame.src = currentSrc })
    }
  }

  #setupInfiniteScroll() {
    this.#intersectionObserver?.disconnect()

    if (!this.hasLoadMoreTriggerTarget || !this.hasScrollableContentTarget) return

    this.#intersectionObserver = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting && this.hasMoreValue && !this.loadingValue) {
            this.#loadMoreNodes()
          }
        })
      },
      {
        root: this.scrollableContentTarget,
        rootMargin: "100px",
        threshold: 0
      }
    )

    this.#intersectionObserver.observe(this.loadMoreTriggerTarget)
  }

  async #loadMoreNodes() {
    if (this.loadingValue || !this.hasMoreValue) return

    this.loadingValue = true
    this.loadingIndicatorTarget?.classList.remove("hidden")

    const newOffset = this.offsetValue + this.limitValue
    const currentParams = new URLSearchParams(window.location.search)
    currentParams.set("offset", newOffset)
    currentParams.set("limit", this.limitValue)

    try {
      const response = await fetch(`/facets/${this.categoryValue}?${currentParams.toString()}`, {
        headers: {
          Accept: "text/html",
          "X-Requested-With": "XMLHttpRequest"
        }
      })

      if (response.ok) {
        const html = await response.text()
        this.loadMoreTriggerTarget?.insertAdjacentHTML("beforebegin", html)

        this.offsetValue = newOffset
        this.hasMoreValue = response.headers.get("X-Has-More") === "true"

        if (!this.hasMoreValue) {
          this.loadMoreTriggerTarget?.remove()
          this.loadingIndicatorTarget?.remove()
        }
      }
    } finally {
      this.loadingValue = false
      this.loadingIndicatorTarget?.classList.add("hidden")
    }
  }

  #intersectionObserver = null
  #boundFrameLoadHandler = null
}
