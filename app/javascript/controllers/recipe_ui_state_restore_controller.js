import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["storage"]

  connect() {
    console.log("DEBUG: recipe_ui_state_restore_controller connected")
    this.findStorageAndRestore()
  }

  findStorageAndRestore() {
    console.log("DEBUG: findStorageAndRestore")

    if (!this.hasStorageTarget) {
      requestAnimationFrame(() => this.findStorageAndRestore())
      return
    }

    this.restorePageState()
  }

  restorePageState(event) {
    if (!this.hasStorageTarget) return

    const pageId = event?.target?.dataset?.pageSlug || "basic-setup"

    requestAnimationFrame(() => {
      const state = JSON.parse(this.storageTarget.value || "{}")
      if (!state.ui_elements_by_page || !state.ui_elements_by_page[pageId]) return

      const pageState = state.ui_elements_by_page[pageId]

      pageState.rails_flag_checkbox_ids.forEach(id => {
        const checkbox = document.querySelector(`input[type="checkbox"][data-element-id="${id}"]`)
        if (checkbox) checkbox.checked = true
      })

      pageState.custom_ingredient_checkbox_ids.forEach(id => {
        const checkbox = document.querySelector(`input[type="checkbox"][data-element-id="${id}"]`)
        if (checkbox) checkbox.checked = true
      })

      Object.entries(pageState.radio_button_selections).forEach(([groupName, selectedId]) => {
        const radio = document.querySelector(`input[type="radio"][data-element-id="${selectedId}"]`)
        if (radio) radio.checked = true
      })
    })
  }
}
