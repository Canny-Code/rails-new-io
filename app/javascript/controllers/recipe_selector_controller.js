import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["radio"]

  connect() {
    // If we have a recipe_id in the URL, make sure the corresponding radio is selected
    const urlParams = new URLSearchParams(window.location.search)
    const recipeId = urlParams.get('recipe_id')
    if (recipeId) {
      const radio = this.radioTargets.find(r => r.value === recipeId)
      if (radio) radio.checked = true
    }
  }

  updateUrl(event) {
    const recipeId = event.target.value
    const url = new URL(window.location)
    url.searchParams.set('recipe_id', recipeId)
    history.pushState({}, '', url)
  }
}
