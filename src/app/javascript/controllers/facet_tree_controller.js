import { Controller } from "@hotwired/stimulus"

// FacetTreeController handles tree node interactions:
// - Toggle node expand/collapse
// - Lazy load children via Turbo Frame
// - Cascade selection to children
//
// @example HTML usage
//   <div data-controller="facet-tree" data-facet-tree-category-value="tissue">
//     <div data-facet-tree-target="treeNode" data-node-id="abc-123">
//       <button data-action="click->facet-tree#toggleNode" data-node-id="abc-123">
//         <svg data-facet-tree-target="nodeChevron">...</svg>
//       </button>
//       <input type="checkbox" data-action="change->facet-tree#handleSelection">
//     </div>
//     <div data-facet-tree-target="childrenContainer" data-parent-id="abc-123" class="hidden">
//       <turbo-frame id="children_abc-123" src="/facets/tissue/children?parent_id=abc-123">
//     </div>
//   </div>
//
export default class extends Controller {
  static targets = ["treeNode", "nodeChevron", "childrenContainer"]

  static values = {
    category: String
  }

  connect() {
    // Listen for restore events from parent panel controller
    this.element.addEventListener("facet-panel:restore-expanded-nodes", this.#handleRestoreNodes.bind(this))
  }

  toggleNode(event) {
    event.preventDefault()
    event.stopPropagation()

    const button = event.currentTarget
    const nodeId = button.dataset.nodeId
    const childContainer = this.element.querySelector(`[data-parent-id="${nodeId}"]`)

    if (!childContainer) return

    const isHidden = childContainer.classList.contains("hidden")
    const chevron = button.querySelector("[data-facet-tree-target='nodeChevron']")

    if (isHidden) {
      this.#expandNode(childContainer, chevron)
    } else {
      this.#collapseNode(childContainer, chevron)
    }

    // Notify parent for state persistence
    this.dispatch("node-toggled", { detail: { nodeId, expanded: isHidden } })
  }

  handleSelection(event) {
    const checkbox = event.target

    if (checkbox.checked) {
      this.#cascadeSelection(checkbox)
    } else {
      this.#clearCascadedMarkers(checkbox)
    }

    // Notify parent panel controller
    this.dispatch("selection-changed", { bubbles: true, prefix: "facet" })
  }

  expandNodeById(nodeId) {
    const childContainer = this.element.querySelector(`[data-parent-id="${nodeId}"]`)
    if (!childContainer || !childContainer.classList.contains("hidden")) return

    const button = this.element.querySelector(`button[data-node-id="${nodeId}"]`)
    if (!button) return

    const chevron = button.querySelector("[data-facet-tree-target='nodeChevron']")
    this.#expandNode(childContainer, chevron)
  }

  // Private

  #handleRestoreNodes(event) {
    const { nodeIds } = event.detail || {}
    if (!nodeIds?.length) return

    requestAnimationFrame(() => {
      nodeIds.forEach(nodeId => this.expandNodeById(nodeId))
    })
  }

  #expandNode(container, chevron) {
    container.classList.remove("hidden")
    if (chevron) chevron.style.transform = "rotate(90deg)"

    // Trigger lazy load if needed
    const frame = container.querySelector("turbo-frame")
    if (frame?.src && !frame.querySelector(".tree-node")) {
      frame.setAttribute("loading", "eager")
      const currentSrc = frame.src
      frame.src = ""
      requestAnimationFrame(() => { frame.src = currentSrc })
    }
  }

  #collapseNode(container, chevron) {
    container.classList.add("hidden")
    if (chevron) chevron.style.transform = "rotate(0deg)"
  }

  #cascadeSelection(checkbox) {
    const treeNode = checkbox.closest("[data-facet-tree-target='treeNode']")
    const nodeId = treeNode?.dataset.nodeId
    if (!nodeId) return

    const childrenContainer = this.element.querySelector(`[data-parent-id="${nodeId}"]`)
    childrenContainer?.querySelectorAll("input[type='checkbox']").forEach(cb => {
      if (!cb.checked) {
        cb.checked = true
        // Mark as cascaded (won't submit separately)
        cb.dataset.originalName = cb.name
        cb.removeAttribute("name")
      }
    })
  }

  #clearCascadedMarkers(checkbox) {
    const treeNode = checkbox.closest("[data-facet-tree-target='treeNode']")
    const nodeId = treeNode?.dataset.nodeId
    if (!nodeId) return

    const childrenContainer = this.element.querySelector(`[data-parent-id="${nodeId}"]`)
    childrenContainer?.querySelectorAll("input[type='checkbox'][data-original-name]").forEach(cb => {
      cb.checked = false
      cb.name = cb.dataset.originalName
      delete cb.dataset.originalName
    })
  }
}
