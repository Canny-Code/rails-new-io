import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["appName", "apiFlag", "databaseChoice", "railsFlags"]

  connect() {
    this.updateFromDisplay()
  }

  updateFromDisplay() {
    const apiFlag = document.getElementById("api-flag")
    const databaseChoice = document.getElementById("database-choice")
    const railsFlags = document.getElementById("rails-flags")

    if (apiFlag) this.apiFlagTarget.value = apiFlag.textContent.trim()
    if (databaseChoice) this.databaseChoiceTarget.value = databaseChoice.textContent.trim()
    if (railsFlags) this.railsFlagsTarget.value = railsFlags.textContent.trim()
  }
}
