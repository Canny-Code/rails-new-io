import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input"]
  static outlets = ["generated-output"]

  connect() {
    if (this.inputTarget.value.trim()) {
      this.update()
    }
  }

  update(event) {
    const value = event?.target?.value?.trim() || this.inputTarget.value.trim() || ""
    this.generatedOutputOutlet.updateText(value)
    this.dispatch("valueChanged", { detail: { value } })
    this.dispatch("appNameChanged", { detail: { value } })
  }
}
