import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static outlets = ["generated-output"]

  connect() {
    // Skip update if we're in rehydration mode
    if(document.getElementById('recipe-rehydration-radio')) return;

    // update() is needed because a radio button group's default selection
    // might add a flag to the terminal output
    this.update()
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
