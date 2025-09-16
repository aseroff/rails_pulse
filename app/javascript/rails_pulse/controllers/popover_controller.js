import { Controller } from "@hotwired/stimulus"
import { computePosition, flip, shift, offset, autoUpdate } from "@floating-ui/dom"

/**
 * Popover Stimulus Controller
 *
 * Usage:
 *   <div data-controller="popover" data-popover-placement-value="top">
 *     <button data-popover-target="button" data-action="click->popover#toggle">Toggle</button>
 *     <div data-popover-target="menu" popover>Menu content</div>
 *   </div>
 *
 * Targets:
 *   - button: The element that triggers the popover
 *   - menu: The popover content element
 *
 * Values:
 *   - placement: Controls popover positioning (default: "top")
 *     Valid values: "top", "top-start", "top-end", "bottom", "bottom-start",
 *     "bottom-end", "left", "left-start", "left-end", "right", "right-start", "right-end"
 *
 * Features:
 *   - Auto-positioning with collision detection
 *   - Lazy loading of operation details via Turbo frames
 *   - CSP-compliant styling using CSS custom properties
 */

export default class extends Controller {
  static targets = [ "button", "menu" ]
  static values  = { placement: { type: String, default: "top" } }

  #showTimer = null
  #hideTimer = null

  initialize() {
    this.orient = this.orient.bind(this)
  }

  connect() {
    this.cleanup = autoUpdate(this.buttonTarget, this.menuTarget, this.orient)
  }

  disconnect() {
    this.cleanup()
  }

  show(event) {
    if (event) event.preventDefault()
    this.menuTarget.showPopover({ source: this.buttonTarget })
    // Explicitly call orient after showing to ensure positioning
    this.orient()
    this.loadOperationDetailsIfNeeded()
  }

  hide() {
    this.menuTarget.hidePopover()
  }

  toggle(event) {
    event.preventDefault()
    this.menuTarget.togglePopover({ source: this.buttonTarget })
    // Explicitly call orient after toggling to ensure positioning
    this.orient()
    this.loadOperationDetailsIfNeeded()
  }

  debouncedShow() {
    clearTimeout(this.#hideTimer)
    this.#showTimer = setTimeout(() => this.show(), 700)
  }

  debouncedHide() {
    clearTimeout(this.#showTimer)
    this.#hideTimer = setTimeout(() => this.hide(), 300)
  }

  orient() {
    computePosition(this.buttonTarget, this.menuTarget, this.#options).then(({x, y}) => {
      // Use CSS custom properties for CSP compliance
      this.menuTarget.style.setProperty('--popover-x', `${x}px`)
      this.menuTarget.style.setProperty('--popover-y', `${y}px`)
      // Add class to apply the positioning
      this.menuTarget.classList.add('positioned')
    })
  }

  loadOperationDetailsIfNeeded() {
    // Check if this popover has operation details to load
    const operationUrl = this.menuTarget.dataset.operationUrl
    if (!operationUrl) return

    // Find the turbo frame inside the popover
    const turboFrame = this.menuTarget.querySelector('turbo-frame')
    if (!turboFrame) return

    // Only load if not already loaded (check if still shows loading content)
    // Use CSP-safe method to check for loading content
    const hasLoadingContent = this.hasLoadingContent(turboFrame)
    if (!hasLoadingContent) return

    // Set the src attribute to trigger the turbo frame loading
    turboFrame.src = operationUrl
  }

  // CSP-safe method to check for loading content
  hasLoadingContent(element) {
    // Use textContent instead of innerHTML to avoid CSP issues
    const textContent = element.textContent || ''
    return textContent.includes('Loading operation details')
  }

  get #options() {
    return { placement: this.placementValue, middleware: [offset(4), flip(), shift({padding: 4})] }
  }
}
