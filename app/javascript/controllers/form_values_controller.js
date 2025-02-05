import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "appName",
    "apiFlag",
    "databaseChoice",
    "javascriptChoice",
    "cssChoice",
    "railsFlags",
    "customIngredients"
  ]

  connect() {
    this.updateFromDisplay()
  }

  updateFromDisplay() {
    if (this.hasApiFlagTarget) this.apiFlagTarget.value = this.getDisplayValue("api-flag")
    if (this.hasDatabaseChoiceTarget) this.databaseChoiceTarget.value = this.getDisplayValue("database-choice")
    if (this.hasJavascriptChoiceTarget) this.javascriptChoiceTarget.value = this.getDisplayValue("javascript-choice")
    if (this.hasCssChoiceTarget) this.cssChoiceTarget.value = this.getDisplayValue("css-choice")
    if (this.hasRailsFlagsTarget) this.railsFlagsTarget.value = this.getDisplayValue("rails-flags")
    if (this.hasCustomIngredientsTarget) this.customIngredientsTarget.value = this.getDisplayValue("custom_ingredients")
  }

  getDisplayValue(id) {
    const element = document.getElementById(id)
    return element ? element.textContent.trim() : ""
  }
}
