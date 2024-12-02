import { Controller } from "@hotwired/stimulus"
import { debounce } from "../utils/debounce"

export default class extends Controller {
  static targets = ["input", "message", "spinner"]
  static values = {
    checkUrl: String,
    debounce: { type: Number, default: 500 }
  }

  static classes = ["error", "success"]

  initialize() {
    this.debouncedValidate = debounce(
      this.performValidation.bind(this),
      this.debounceValue
    )
  }

  validate() {
    this.spinnerTarget.classList.remove('hidden')
    this.messageTarget.classList.add('hidden')
    this.debouncedValidate()
  }

  async performValidation() {
    const name = this.inputTarget.value
    const valid = this.validateFormat(name)

    this.spinnerTarget.classList.add('hidden')

    if (!valid) {
      this.showMessage("Invalid format. Use only letters, numbers, and single hyphens.", "error")
      return
    }

    try {
      const available = await this.checkAvailability(name)
      if (!available) {
        this.showMessage("Repository name already taken", "error")
        return
      }
      this.showMessage("Name available", "success")
    } catch (error) {
      // Error message already shown by checkAvailability
      return
    }
  }

  validateFormat(name) {
    const regex = /^[a-zA-Z0-9][a-zA-Z0-9-]*[a-zA-Z0-9]$/
    return regex.test(name) && !name.includes('--')
  }

  async checkAvailability(name) {
    try {
      const response = await fetch(`${this.checkUrlValue}?name=${encodeURIComponent(name)}`)
      if (!response.ok) throw new Error('Network response was not ok')
      const data = await response.json()
      return data.available
    } catch (error) {
      console.error('Error checking availability:', error)
      this.showMessage("Error checking availability", "error")
      throw error
    }
  }

  showMessage(message, type) {
    this.messageTarget.textContent = message
    this.messageTarget.classList.remove("hidden", this.errorClasses, this.successClasses)
    this.messageTarget.classList.add(type === "error" ? this.errorClasses : this.successClasses)
  }

  hideMessage() {
    this.messageTarget.classList.add("hidden")
  }
}
