import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static outlets = ["generated-output"]

  connect() {
    if (this.hasGeneratedOutputOutlet) {
      this.update()
    }
  }

  update() {
    const groupElement = this.element.closest('ul')
    const checkboxes = groupElement.querySelectorAll('input[type="checkbox"]')
    const isCustomIngredient = this.generatedOutputOutlet.element.id === 'custom_ingredients'

    const selectedValues = Array.from(checkboxes).map(checkbox => {
      const displayWhen = checkbox.dataset.displayWhen || 'checked'
      const isChecked = checkbox.checked

      if ((displayWhen === 'checked' && isChecked) ||
          (displayWhen === 'unchecked' && !isChecked)) {
        if (isCustomIngredient) {
          const label = checkbox.closest('label')?.querySelector('.menu-card-row-title')?.textContent.trim()
          return label || ''
        }
        return checkbox.dataset.commandOutput || checkbox.value.toLowerCase()
      }
      return ''
    }).filter(Boolean)

    let outputText = groupElement.dataset.outputPrefix ?
      `${groupElement.dataset.outputPrefix} ${selectedValues.join(' ')}` :
      selectedValues.join(' ');

    if (this.hasGeneratedOutputOutlet) {
      this.generatedOutputOutlet.updateText(outputText)
    }
  }
}
