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
    this.form = document.getElementById('search_form')
    this.updateGlobalSelections()
    this.loadSavedState()
    this.updateSelectedCount()

    const hasSelected = this.element.querySelectorAll('input[type="checkbox"]:checked').length > 0
    if (hasSelected && !this.expandedValue) {
      this.expandedValue = true
      this.expand(false)
    }

    this.frameLoadHandler = this.handleFrameLoad.bind(this)
    document.addEventListener('turbo:frame-load', this.frameLoadHandler)

    setTimeout(() => this.setupInfiniteScroll(), 100)
  }

  handleFrameLoad(event) {
    if (this.element.contains(event.target)) {
      this.updateSelectedCount()

      if (this.hasPaginationDataTarget) {
        const paginationData = this.paginationDataTarget
        this.hasMoreValue = paginationData.dataset.hasMore === 'true'
        this.offsetValue = parseInt(paginationData.dataset.offset, 10) || 0

        setTimeout(() => this.setupInfiniteScroll(), 100)
      }
    }
  }

  disconnect() {
    this.saveState()

    if (this.frameLoadHandler) {
      document.removeEventListener('turbo:frame-load', this.frameLoadHandler)
    }

    if (this.intersectionObserver) {
      this.intersectionObserver.disconnect()
      this.intersectionObserver = null
    }
  }

  toggleExpand(event) {
    if (event) {
      event.preventDefault()
      event.stopPropagation()
    }

    this.expandedValue = !this.expandedValue

    if (this.expandedValue) {
      this.expand()
    } else {
      this.collapse()
    }

    this.saveState()
  }

  expand(autoFocus = true) {
    this.lazyLoadContentIfNeeded()

    this.scrollableContentTarget.style.maxHeight = this.expandedHeightValue
    this.chevronTarget.style.transform = 'rotate(90deg)'

    if (this.hasSearchContainerTarget) {
      this.searchContainerTarget.classList.remove('hidden')

      if (autoFocus) {
        setTimeout(() => {
          if (this.hasSearchInputTarget) {
            this.searchInputTarget.focus()
          }
        }, 200)
      }
    }
  }

  lazyLoadContentIfNeeded() {
    if (!this.hasContentFrameTarget) return

    const frame = this.contentFrameTarget

    if (frame.dataset.loaded === 'true' || frame.hasAttribute('src')) {
      return
    }

    const currentParams = new URLSearchParams(window.location.search)
    const url = `/facets/${this.categoryValue}?${currentParams.toString()}`

    frame.setAttribute('src', url)
    frame.dataset.loaded = 'true'
  }

  collapse() {
    this.scrollableContentTarget.style.maxHeight = this.collapsedHeightValue
    this.chevronTarget.style.transform = 'rotate(0deg)'

    if (this.hasSearchContainerTarget) {
      this.searchContainerTarget.classList.add('hidden')
    }
  }

  handleSelection(event) {
    const checkbox = event.target

    if (checkbox.checked) {
      this.cascadeSelection(checkbox)
    } else {
      this.clearCascadedMarkers(checkbox)
    }

    this.updateSelectedCount()
    this.saveState()

    if (this.form) {
      this.form.requestSubmit()
    }
  }

  cascadeSelection(checkbox) {
    const treeNode = checkbox.closest('[data-facet-panel-target="treeNode"]')
    if (!treeNode) return

    const nodeId = treeNode.dataset.nodeId
    if (!nodeId) return

    const childrenContainer = this.element.querySelector(`[data-parent-id="${nodeId}"]`)
    if (!childrenContainer) return

    const descendantCheckboxes = childrenContainer.querySelectorAll('input[type="checkbox"]')
    descendantCheckboxes.forEach(cb => {
      if (!cb.checked) {
        cb.checked = true
        cb.dataset.originalName = cb.name
        cb.removeAttribute('name')
      }
    })
  }

  clearCascadedMarkers(checkbox) {
    const treeNode = checkbox.closest('[data-facet-panel-target="treeNode"]')
    if (!treeNode) return

    const nodeId = treeNode.dataset.nodeId
    if (!nodeId) return

    const childrenContainer = this.element.querySelector(`[data-parent-id="${nodeId}"]`)
    if (!childrenContainer) return

    const descendantCheckboxes = childrenContainer.querySelectorAll('input[type="checkbox"][data-original-name]')
    descendantCheckboxes.forEach(cb => {
      cb.checked = false
      cb.name = cb.dataset.originalName
      delete cb.dataset.originalName
    })
  }

  updateSelectedCount() {
    const checkboxes = this.element.querySelectorAll('input[type="checkbox"]:checked')
    let count = checkboxes.length

    if (!this.contentLoaded()) {
      const paramKey = this.getParamKey()
      const urlParams = new URLSearchParams(window.location.search)
      const selectedFromUrl = urlParams.getAll(`${paramKey}[]`)
      count = selectedFromUrl.length
    }

    if (count > 0) {
      if (this.hasSelectedBadgeTarget) {
        this.selectedBadgeTarget.textContent = count
        this.selectedBadgeTarget.classList.remove('hidden')
      }
      if (this.hasClearButtonTarget) {
        this.clearButtonTarget.classList.remove('hidden')
      }
    } else {
      if (this.hasSelectedBadgeTarget) {
        this.selectedBadgeTarget.classList.add('hidden')
      }
      if (this.hasClearButtonTarget) {
        this.clearButtonTarget.classList.add('hidden')
      }
    }

    this.updateGlobalSelections()
  }

  contentLoaded() {
    if (!this.hasContentFrameTarget) return true
    const frame = this.contentFrameTarget
    return frame.dataset.loaded === 'true' && this.element.querySelector('input[type="checkbox"]') !== null
  }

  updateGlobalSelections() {
    const checkboxes = this.element.querySelectorAll('input[type="checkbox"]:checked')
    let selectedIds = Array.from(checkboxes).map(cb => cb.value)

    if (!this.contentLoaded() && selectedIds.length === 0) {
      const paramKey = this.getParamKey()
      const urlParams = new URLSearchParams(window.location.search)
      selectedIds = urlParams.getAll(`${paramKey}[]`)
    }

    const paramKey = this.getParamKey()
    sessionStorage.setItem(`selections_${paramKey}`, JSON.stringify(selectedIds))
  }

  getParamKey() {
    const category = this.categoryValue
    const pluralMap = {
      'organism': 'organisms',
      'tissue': 'tissues',
      'developmental_stage': 'developmental_stages',
      'disease': 'diseases',
      'sex': 'sexes',
      'technology': 'technologies'
    }
    return pluralMap[category] || category
  }

  clearCategory(event) {
    event.preventDefault()
    event.stopPropagation()

    const checkboxes = this.element.querySelectorAll('input[type="checkbox"]:checked')
    checkboxes.forEach(cb => { cb.checked = false })

    if (this.hasSearchInputTarget) {
      this.searchInputTarget.value = ''
      this.clearSearch()
    }

    const paramKey = this.getParamKey()
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
    const frameId = button.dataset.treeFrameId
    const childContainer = this.element.querySelector(`[data-parent-id="${nodeId}"]`)

    if (!childContainer) return

    const isHidden = childContainer.classList.contains('hidden')
    const chevron = button.querySelector('[data-facet-panel-target="nodeChevron"]')

    if (isHidden) {
      childContainer.classList.remove('hidden')
      if (chevron) chevron.style.transform = 'rotate(90deg)'

      const frame = document.getElementById(frameId)
      if (frame && frame.dataset.loaded !== 'true') {
        const currentParams = new URLSearchParams(window.location.search)
        currentParams.set('parent_id', nodeId)
        currentParams.delete('format')

        const url = `/facets/${this.categoryValue}/children?${currentParams.toString()}`
        frame.setAttribute('src', url)
        frame.dataset.loaded = 'true'
        frame.reload()
      }
    } else {
      childContainer.classList.add('hidden')
      if (chevron) chevron.style.transform = 'rotate(0deg)'
    }

    this.saveState()
  }

  searchInput(event) {
    if (this.searchTimeout) clearTimeout(this.searchTimeout)

    const searchValue = event.target.value.trim()

    this.toggleClearButton(searchValue)

    if (!searchValue) {
      this.clearSearch()
      return
    }

    if (searchValue.length < 2) return

    this.searchTimeout = setTimeout(() => this.updateFrameSrc(searchValue), 200)
  }

  toggleClearButton(searchValue) {
    if (!this.hasClearSearchButtonTarget) return

    if (searchValue) {
      this.clearSearchButtonTarget.classList.remove('hidden')
    } else {
      this.clearSearchButtonTarget.classList.add('hidden')
    }
  }

  updateFrameSrc(query) {
    if (!this.hasContentFrameTarget) return

    const url = `/facets/${this.categoryValue}/search?q=${encodeURIComponent(query)}`
    this.contentFrameTarget.src = url
  }

  clearSearch(event) {
    if (event) {
      event.preventDefault()
      event.stopPropagation()
    }

    if (this.hasSearchInputTarget) {
      this.searchInputTarget.value = ''
    }

    this.toggleClearButton('')

    if (this.hasContentFrameTarget) {
      const currentParams = new URLSearchParams(window.location.search)
      const url = `/facets/${this.categoryValue}?${currentParams.toString()}`
      this.contentFrameTarget.src = url
    }
  }

  saveState() {
    const expandedNodes = []
    this.element.querySelectorAll('[data-facet-panel-target="childrenContainer"]:not(.hidden)').forEach(container => {
      if (container.dataset.parentId) {
        expandedNodes.push(container.dataset.parentId)
      }
    })

    const state = {
      expanded: this.expandedValue,
      scrollTop: this.scrollableContentTarget.scrollTop,
      searchTerm: this.hasSearchInputTarget ? this.searchInputTarget.value : '',
      expandedNodes
    }

    sessionStorage.setItem(`facet-${this.categoryValue}`, JSON.stringify(state))
  }

  loadSavedState() {
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

      if (state.expandedNodes && state.expandedNodes.length > 0) {
        requestAnimationFrame(() => {
          state.expandedNodes.forEach(nodeId => this.expandNodeById(nodeId))
        })
      }
    } catch (e) {
      console.error('Failed to restore facet state:', e)
    }
  }

  expandNodeById(nodeId) {
    const childContainer = this.element.querySelector(`[data-parent-id="${nodeId}"]`)
    if (!childContainer || !childContainer.classList.contains('hidden')) return

    childContainer.classList.remove('hidden')

    const button = this.element.querySelector(`button[data-node-id="${nodeId}"]`)
    if (!button) return

    const chevron = button.querySelector('[data-facet-panel-target="nodeChevron"]')
    if (chevron) chevron.style.transform = 'rotate(90deg)'

    const frameId = button.dataset.treeFrameId
    const frame = document.getElementById(frameId)
    if (frame) {
      const currentParams = new URLSearchParams(window.location.search)
      currentParams.set('parent_id', nodeId)
      currentParams.delete('format')

      const url = `/facets/${this.categoryValue}/children?${currentParams.toString()}`
      frame.setAttribute('src', url)
      frame.dataset.loaded = 'true'
      frame.reload()
    }
  }

  setupInfiniteScroll() {
    if (this.intersectionObserver) {
      this.intersectionObserver.disconnect()
    }

    if (!this.hasLoadMoreTriggerTarget || !this.hasScrollableContentTarget) return

    this.intersectionObserver = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting && this.hasMoreValue && !this.loadingValue) {
            this.loadMoreNodes()
          }
        })
      },
      {
        root: this.scrollableContentTarget,
        rootMargin: '100px',
        threshold: 0
      }
    )

    this.intersectionObserver.observe(this.loadMoreTriggerTarget)
  }

  async loadMoreNodes() {
    if (this.loadingValue || !this.hasMoreValue) return

    this.loadingValue = true
    this.showLoadingIndicator()

    const newOffset = this.offsetValue + this.limitValue
    const currentParams = new URLSearchParams(window.location.search)
    currentParams.set('offset', newOffset)
    currentParams.set('limit', this.limitValue)

    const url = `/facets/${this.categoryValue}?${currentParams.toString()}`

    try {
      const response = await fetch(url, {
        headers: {
          'Accept': 'text/html',
          'X-Requested-With': 'XMLHttpRequest'
        }
      })

      if (response.ok) {
        const html = await response.text()

        if (this.hasLoadMoreTriggerTarget) {
          this.loadMoreTriggerTarget.insertAdjacentHTML('beforebegin', html)
        }

        this.offsetValue = newOffset
        this.hasMoreValue = response.headers.get('X-Has-More') === 'true'

        if (!this.hasMoreValue) {
          this.hideTriggerAndLoading()
        }
      }
    } catch (error) {
      console.error('Failed to load more nodes:', error)
    } finally {
      this.loadingValue = false
      this.hideLoadingIndicator()
    }
  }

  showLoadingIndicator() {
    if (this.hasLoadingIndicatorTarget) {
      this.loadingIndicatorTarget.classList.remove('hidden')
    }
  }

  hideLoadingIndicator() {
    if (this.hasLoadingIndicatorTarget) {
      this.loadingIndicatorTarget.classList.add('hidden')
    }
  }

  hideTriggerAndLoading() {
    if (this.hasLoadMoreTriggerTarget) {
      this.loadMoreTriggerTarget.remove()
    }
    if (this.hasLoadingIndicatorTarget) {
      this.loadingIndicatorTarget.remove()
    }
  }

  resetPagination() {
    this.offsetValue = 0
    this.hasMoreValue = true
    this.loadingValue = false
  }
}