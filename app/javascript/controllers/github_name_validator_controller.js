import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "message", "spinner", "submitButton"]
  static values = {
    checkUrl: String,
    debounce: { type: Number, default: 500 },
    errorClass: { type: String, default: "text-red-600" },
    successClass: { type: String, default: "text-green-600" }
  }

  initialize() {
    this.validate = this.debounce(this.validate.bind(this), this.debounceValue)
    this.disableSubmit()
    this.boundValidate = this.validate.bind(this)
  }

  connect() {
    document.addEventListener("app-name-preview:appNameChanged", this.boundValidate)
  }

  disconnect() {
    document.removeEventListener("app-name-preview:appNameChanged", this.boundValidate)
  }

  async validate(event) {
    if (!this.hasInputTarget || !this.hasMessageTarget || !this.hasSpinnerTarget || !this.hasSubmitButtonTarget) {
      return
    }

    const name = event?.detail?.value || ''
    if (!name) {
      this.hideMessage()
      this.disableSubmit()
      return
    }

    this.showSpinner()

    try {
      const response = await fetch(`${this.checkUrlValue}?name=${encodeURIComponent(name)}`)

      if (!response.ok) {
        const error = await response.json()
        throw new Error(error.error || 'Failed to validate repository name')
      }

      const data = await response.json()

      this.hideSpinner()

      if (data.available) {
        this.enableSubmit()
        this.showMessage("✓ Name is available", this.successClassValue)
      } else {
        this.disableSubmit()
        this.showMessage("✗ Name is already taken", this.errorClassValue)
      }
    } catch (error) {
      this.hideSpinner()
      this.disableSubmit()
      this.showMessage("Error checking name availability", this.errorClassValue)
    }
  }

  showMessage(text, className) {
    this.messageTarget.textContent = text
    this.messageTarget.className = `${className} text-sm mt-1`
    this.messageTarget.classList.remove("hidden")
  }

  hideMessage() {
    this.messageTarget.classList.add("hidden")
  }

  showSpinner() {
    this.spinnerTarget.classList.remove("hidden")
    this.hideMessage()
  }

  hideSpinner() {
    this.spinnerTarget.classList.add("hidden")
  }

  debounce(func, wait) {
    let timeout
    return function executedFunction(...args) {
      const later = () => {
        clearTimeout(timeout)
        func(...args)
      }
      clearTimeout(timeout)
      timeout = setTimeout(later, wait)
    }
  }

  disableSubmit() {
    this.submitButtonTarget.disabled = true
    this.submitButtonTarget.classList.add('opacity-50', 'cursor-not-allowed')
  }

  enableSubmit() {
    this.submitButtonTarget.disabled = false
    this.submitButtonTarget.classList.remove('opacity-50', 'cursor-not-allowed')
  }
}
