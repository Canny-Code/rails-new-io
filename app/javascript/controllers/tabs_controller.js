import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tab", "panel"]
  static values = {
    currentPage: String
  }

  connect() {
    // Set initial state for the current page
    const currentTab = this.tabTargets.find(tab => tab.classList.contains("tab-active"))
    if (currentTab) {
      window.history.replaceState(
        { pageSlug: currentTab.dataset.pageSlug },
        '',
        window.location.href
      )
    }
    window.addEventListener('popstate', this.handlePopState.bind(this))
  }

  disconnect() {
    window.removeEventListener('popstate', this.handlePopState.bind(this))
  }

  change(event) {
    event.preventDefault()
    const selectedTab = event.currentTarget
    const pageSlug = selectedTab.dataset.pageSlug
    const pageUrl = selectedTab.dataset.pageUrl

    // Validate required data attributes
    if (!pageSlug || !pageUrl) {
      console.error("Missing required data attributes: pageSlug or pageUrl")
      return
    }

    // Don't do anything if clicking the active tab
    if (selectedTab.classList.contains("tab-active")) {
      return
    }

    // Create URL object to preserve existing query parameters
    const currentUrl = new URL(window.location.href)
    const newUrl = new URL(pageUrl, window.location.origin)

    // Copy over existing query parameters
    currentUrl.searchParams.forEach((value, key) => {
      newUrl.searchParams.set(key, value)
    })

    // Update URL without reloading the page
    window.history.pushState({ pageSlug }, '', newUrl)

    this.switchToTab(selectedTab)
  }

  handlePopState(event) {
    // Try to get the page slug from state, fallback to current page value, then to first tab
    const pageSlug = event.state?.pageSlug || this.currentPageValue
    let tab = this.tabTargets.find(t => t.dataset.pageSlug === pageSlug)

    // If no matching tab found, default to first tab
    if (!tab && this.tabTargets.length > 0) {
      console.warn(`No tab found for slug: ${pageSlug}, defaulting to first tab`)
      tab = this.tabTargets[0]
      // Update history state to match actual tab
      window.history.replaceState(
        { pageSlug: tab.dataset.pageSlug },
        '',
        tab.dataset.pageUrl
      )
    }

    if (tab) {
      this.switchToTab(tab)
    } else {
      console.error("No tabs available")
    }
  }

  switchToTab(selectedTab) {
    if (!selectedTab) {
      console.error("No tab provided to switch to")
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

    // Show selected panel, hide others
    const selectedPanelId = `${selectedTab.dataset.pageSlug}-panel`
    let panelFound = false

    this.panelTargets.forEach(panel => {
      if (panel.id === selectedPanelId) {
        panel.classList.remove("hidden")
        panelFound = true
      } else {
        panel.classList.add("hidden")
      }
    })

    if (!panelFound) {
      console.error(`No panel found with id: ${selectedPanelId}`)
    }
  }
}
