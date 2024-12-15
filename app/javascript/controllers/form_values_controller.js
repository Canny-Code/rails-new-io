import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["appName", "apiFlag", "databaseChoice", "railsFlags"]

  connect() {
    // Initialize values from the command display
    this.updateFromDisplay()
  }

  updateFromDisplay() {
    const appNameOutput = document.getElementById("app-name-output")
    const apiFlag = document.getElementById("api-flag")
    const databaseChoice = document.getElementById("database-choice")
    const railsFlags = document.getElementById("rails-flags")

    if (appNameOutput) {
      this.appNameTarget.value = appNameOutput.textContent.trim()
      const event = new Event('input', { bubbles: true })
      this.appNameTarget.dispatchEvent(event)
    }
    if (apiFlag) this.apiFlagTarget.value = apiFlag.textContent.trim()
    if (databaseChoice) this.databaseChoiceTarget.value = databaseChoice.textContent.trim()
    if (railsFlags) this.railsFlagsTarget.value = railsFlags.textContent.trim()
  }
}
