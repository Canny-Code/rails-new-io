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
    const railsOutputEntry = this.containerTarget.querySelector('[data-entry-type="rails_output"]')
    if (railsOutputEntry) {
      const container = this.containerTarget
      const entryTop = railsOutputEntry.offsetTop
      const entryHeight = railsOutputEntry.offsetHeight
      const containerHeight = container.clientHeight

      // Calculate position to show the bottom of the rails_output entry
      const scrollPosition = entryTop + entryHeight - containerHeight
      container.scrollTop = scrollPosition

      console.log("Scrolled to rails output bottom", {
        entryTop,
        entryHeight,
        containerHeight,
        scrollPosition
      })
    } else {
      this.containerTarget.scrollTop = 0
      console.log("No rails output found, scrolled to top")
    }
  }

  setupMutationObserver() {
    this.observer = new MutationObserver((mutations) => {
      console.log("Mutation detected:", mutations)
      this.scrollToBottom()
    })

    this.observer.observe(this.containerTarget, {
      childList: true,
      subtree: true,
      characterData: true,
      characterDataOldValue: true
    })
  }
}
