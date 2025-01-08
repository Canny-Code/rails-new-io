import { Controller } from "@hotwired/stimulus"
import { visit } from "@hotwired/turbo"

export default class extends Controller {
  static targets = ["tab", "panel"]

  connect() {
    console.log("Tabs controller connected!")
    // Only show the first tab if no tab is active
    if (!this.tabTargets.find(tab => tab.classList.contains("tab-active"))) {
      this.showTab(this.tabTargets[0])
    }
  }

  change(event) {
    event.preventDefault()
    const selectedTab = event.currentTarget

    // Don't do anything if clicking the active tab
    if (selectedTab.classList.contains("tab-active")) {
      return
    }

    // Update tab classes
    this.tabTargets.forEach(tab => {
      if (tab === selectedTab) {
        tab.classList.remove("tab-inactive")
        tab.classList.add("tab-active")
      } else {
        tab.classList.remove("tab-active")
        tab.classList.add("tab-inactive")
      }
    })

    // Navigate to the new page using Turbo
    const pageUrl = selectedTab.getAttribute("href")
    if (pageUrl && pageUrl !== "#") {
      visit(pageUrl)
    }
  }
}
