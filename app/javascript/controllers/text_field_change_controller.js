import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input"]
  static outlets = ["generated-output"]

  connect() {
    this.update()
  }

  update(event) {
    const inputValue = this.inputTarget.value || this.inputTarget.dataset.defaultValue || ""
    const prefix = this.inputTarget.dataset.outputPrefix || ""

    const updatedText = prefix ? `${prefix} ${inputValue}` : inputValue
    this.generatedOutputOutlet.updateText(updatedText)
  }
}
