import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tab", "panel"]

  connect() {
    console.log("Tabs controller connected!")
    this.showTab(this.tabTargets[0])
  }

  change(event) {
    event.preventDefault()
    console.log("Click event triggered")
    console.log("Current classes:", event.currentTarget.classList.toString())
    this.showTab(event.currentTarget)
  }

  showTab(selectedTab) {
    console.log("showTab called with:", selectedTab.id)
    console.log("Classes before change:", selectedTab.classList.toString())
    
    const activeTab = this.tabTargets.find(tab => 
      tab.classList.contains("tab-active")
    )

    if (activeTab === selectedTab) {
      console.log("Same tab clicked, returning")
      return 
    }

    if (activeTab) {
      console.log("Deactivating current tab:", activeTab.id)
      activeTab.classList.remove("tab-active")
      activeTab.classList.add("tab-inactive")
      
      const activePanelId = activeTab.id.replace('-tab', '-tab-panel')
      document.getElementById(activePanelId).hidden = true
    }

    console.log("Activating new tab:", selectedTab.id)
    selectedTab.classList.remove("tab-inactive")
    selectedTab.classList.add("tab-active")
    
    const selectedPanelId = selectedTab.id.replace('-tab', '-tab-panel')
    document.getElementById(selectedPanelId).hidden = false
  }
} 