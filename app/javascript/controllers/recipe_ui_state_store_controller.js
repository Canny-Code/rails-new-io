// app/javascript/controllers/recipe_ui_state_store_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["storage"]

  connect() {
    // Initialize empty state if none exists
    if (!this.storageTarget.value) {
      this.state = {
        ui_elements_by_page: {}
      }
      this.saveState()
    } else {
      this.state = JSON.parse(this.storageTarget.value)
    }
  }

  radioSelected(event) {
    const radio = event.target
    const pageId = this.findPageId(radio)
    if (!pageId) return

    // Initialize page state if needed
    if (!this.state.ui_elements_by_page[pageId]) {
      this.state.ui_elements_by_page[pageId] = {
        rails_flag_checkbox_ids: [],
        custom_ingredient_checkbox_ids: [],
        radio_button_selections: {}
      }
    }

    // Store selection for this group
    const group = radio.name
    this.state.ui_elements_by_page[pageId].radio_button_selections[group] = radio.dataset.elementId

    this.saveState()
  }

  railsFlagChanged(event) {
    const checkbox = event.target
    const pageId = this.findPageId(checkbox)
    if (!pageId) return

    // Initialize page state if needed
    if (!this.state.ui_elements_by_page[pageId]) {
      this.state.ui_elements_by_page[pageId] = {
        rails_flag_checkbox_ids: [],
        custom_ingredient_checkbox_ids: [],
        radio_button_selections: {}
      }
    }

    const ids = this.state.ui_elements_by_page[pageId].rails_flag_checkbox_ids

    if (checkbox.checked) {
      ids.push(checkbox.dataset.elementId)
    } else {
      const index = ids.indexOf(checkbox.dataset.elementId)
      if (index > -1) ids.splice(index, 1)
    }

    this.saveState()
  }

  ingredientChanged(event) {
    const checkbox = event.target
    const pageId = this.findPageId(checkbox)
    if (!pageId) return

    // Initialize page state if needed
    if (!this.state.ui_elements_by_page[pageId]) {
      this.state.ui_elements_by_page[pageId] = {
        rails_flag_checkbox_ids: [],
        custom_ingredient_checkbox_ids: [],
        radio_button_selections: {}
      }
    }

    const ids = this.state.ui_elements_by_page[pageId].custom_ingredient_checkbox_ids

    if (checkbox.checked) {
      ids.push(checkbox.dataset.elementId)
    } else {
      const index = ids.indexOf(checkbox.dataset.elementId)
      if (index > -1) ids.splice(index, 1)
    }

    this.saveState()
  }

  findPageId(element) {
    const pageElement = element.closest('[data-recipe-ui-state-store-page-id-value]')
    return pageElement?.dataset.recipeUiStateStorePageIdValue
  }

  saveState() {
    this.storageTarget.value = JSON.stringify(this.state)
  }
}
