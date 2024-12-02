import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["container"]

  connect() {
    console.log("LogScrollController connected")
    this.setupMutationObserver()
  }

  disconnect() {
    if (this.observer) {
      this.observer.disconnect()
    }
  }

  scrollToBottom() {
    const railsOutputEntry = this.containerTarget.querySelector('[data-entry-type][data-rails-output="true"]')
    if (railsOutputEntry) {
      const container = this.containerTarget
      const entryTop = railsOutputEntry.offsetTop
      const entryHeight = railsOutputEntry.offsetHeight
      const containerHeight = container.clientHeight

      const scrollPosition = entryTop + entryHeight - containerHeight
      container.scrollTop = scrollPosition
    } else {
      this.scrollToTop()
    }
  }

  scrollToTop() {
    this.containerTarget.scrollTop = 0
  }

  setupMutationObserver() {
    this.observer = new MutationObserver((mutations) => {
      const addedNodes = mutations.flatMap(m => Array.from(m.addedNodes))
      const hasRailsOutput = addedNodes.some(node =>
        node.nodeType === Node.ELEMENT_NODE &&
        node.querySelector('[data-rails-output="true"]')
      )

      if (hasRailsOutput) {
        this.scrollToBottom()
      } else {
        this.scrollToTop()
      }
    })

    this.observer.observe(this.containerTarget, {
      childList: true,
      subtree: true
    })
  }
}
