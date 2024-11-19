import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static outlets = ["generated-output"]

  connect() {
    if (this.hasDatabaseChoiceOutlet) {
      this.update()
    }
  }

  update(event) {
    const groupElement = this.element.closest('ul')
    const selectedRadio = groupElement.querySelector('input[type="radio"]:checked')

    const radio_value = selectedRadio ? selectedRadio.value.toLowerCase() : ''

    let outputText = groupElement.dataset.outputPrefix ?
      `${groupElement.dataset.outputPrefix} ${radio_value}` :
      radio_value;

    outputText = selectedRadio.dataset.isDefault === "true" ? '' : outputText

    this.generatedOutputOutlet.updateText(outputText)
  }
}
