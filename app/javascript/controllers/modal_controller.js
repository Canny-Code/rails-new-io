import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modal"]

  connect() {
    // Add event listener for ESC key
    document.addEventListener("keydown", this.handleKeydown.bind(this))
  }

  disconnect() {
    document.removeEventListener("keydown", this.handleKeydown.bind(this))
  }

  open() {
    // Capture current values from the generator
    const apiFlag = document.getElementById("api-flag").textContent
    const databaseChoice = document.getElementById("database-choice").textContent
    const railsFlags = document.getElementById("rails-flags").textContent

    // Set form values
    this.element.querySelector('[data-form-values-target="apiFlag"]').value = apiFlag
    this.element.querySelector('[data-form-values-target="databaseChoice"]').value = databaseChoice
    this.element.querySelector('[data-form-values-target="railsFlags"]').value = railsFlags

    // Show modal
    this.modalTarget.classList.remove("hidden")
    document.body.classList.add("overflow-hidden")
  }

  close() {
    this.modalTarget.classList.add("hidden")
    document.body.classList.remove("overflow-hidden")
  }

  handleKeydown(event) {
    if (event.key === "Escape") {
      this.close()
    }
  }

  // Close if clicking outside of modal content
  clickOutside(event) {
    if (event.target === this.modalTarget) {
      this.close()
    }
  }
}
