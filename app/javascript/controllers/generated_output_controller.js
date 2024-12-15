import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  updateText(text) {
    this.element.innerText = text
    this.dispatch("valueChanged")
  }
}
