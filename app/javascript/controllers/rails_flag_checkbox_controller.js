import { Controller } from "@hotwired/stimulus"

// Handles the Rails flag checkboxes in the UI
export default class extends Controller {
  static targets = ["output"]

  connect() {
    this.groupElement = this.element.closest('ul')
    if (!this.groupElement) return
    this.update()
  }

  update() {
    const checkboxes = this.groupElement.querySelectorAll('input[type="checkbox"]')
    const selectedValues = Array.from(checkboxes)
      .filter(checkbox => {
        const displayWhen = checkbox.dataset.displayWhen || 'checked'
        const isChecked = checkbox.checked
        return (displayWhen === 'checked' && isChecked) ||
               (displayWhen === 'unchecked' && !isChecked)
      })
      .map(checkbox => checkbox.dataset.commandOutput)
      .filter(Boolean)

    const outputElement = document.getElementById('rails-flags')
    outputElement.textContent = selectedValues.join(" ")
  }
}
