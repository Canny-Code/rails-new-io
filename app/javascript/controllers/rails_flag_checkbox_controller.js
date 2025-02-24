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
    // Get current flags from the output element
    const outputElement = document.getElementById('rails-flags')
    const currentFlags = new Set(outputElement?.textContent?.trim().split(/\s+/).filter(Boolean) || [])

    // Remove any existing flags from this group
    const allCheckboxes = this.groupElement.querySelectorAll('input[type="checkbox"]')
    allCheckboxes.forEach(checkbox => {
      if (checkbox.value) {
        currentFlags.delete(checkbox.value)
      }
    })

    // Add currently selected flags from this group
    const selectedCheckboxes = Array.from(allCheckboxes)
      .filter(checkbox => {
        const displayWhen = checkbox.dataset.displayWhen || 'checked'
        const isChecked = checkbox.checked
        return (displayWhen === 'checked' && isChecked) ||
               (displayWhen === 'unchecked' && !isChecked)
      })

    selectedCheckboxes.forEach(checkbox => {
      if (checkbox.value) {
        currentFlags.add(checkbox.value)
      }
    })

    // Update the output with all flags
    if (outputElement) {
      const flags = Array.from(currentFlags)
      outputElement.innerHTML = flags.map(flag =>
        `<span class="inline-block">${flag}</span>`
      ).join(" ")
    }
  }
}
