import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "message", "spinner", "submitButton", "recipeRadio", "inputLabel"]
  static values = {
    checkUrl: String,
    debounce: { type: Number, default: 500 },
    errorClass: { type: String, default: "text-red-600" },
    successClass: { type: String, default: "text-green-600" }
  }

  initialize() {
    this.validate = this.debounce(this.validate.bind(this), this.debounceValue)
    this.disableSubmit()
  }

  connect() {
    this.updateInputState()
    this.validateForm()
  }

  validateForm() {
    const name = this.inputTarget.value.trim()
    const recipeSelected = Array.from(this.recipeRadioTargets).some(radio => radio.checked)

    if (!name || !recipeSelected) {
      this.disableSubmit()
      return
    }

    this.validate()
  }

  async validate() {
    if (!this.hasInputTarget || !this.hasMessageTarget || !this.hasSpinnerTarget || !this.hasSubmitButtonTarget) {
      return
    }

    const name = this.inputTarget.value.trim()
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
        const recipeSelected = Array.from(this.recipeRadioTargets).some(radio => radio.checked)
        if (recipeSelected) {
          this.enableSubmit()
          this.showMessage("✓ Name is available", this.successClassValue)
        } else {
          this.disableSubmit()
          this.showMessage("Please select a recipe", this.errorClassValue)
        }
      } else {
        this.disableSubmit()
        this.showMessage("✗ Name is invalid or already taken", this.errorClassValue)
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
    this.submitButtonTargets.forEach(button => {
      button.disabled = true
      button.classList.add('opacity-50', 'cursor-not-allowed')
    })
  }

  enableSubmit() {
    this.submitButtonTargets.forEach(button => {
      button.disabled = false
      button.classList.remove('opacity-50', 'cursor-not-allowed')
    })
  }

  recipeSelected(event) {
    this.updateInputState()
    this.validateForm()
  }

  updateInputState() {
    const recipeSelected = Array.from(this.recipeRadioTargets).some(radio => radio.checked)

    if (recipeSelected) {
      this.inputTarget.disabled = false
      this.inputLabelTarget.textContent = "Enter the name of your awesome app!"
    } else {
      this.inputTarget.disabled = true
      this.inputLabelTarget.textContent = "Select a recipe from the list below ↓"
    }
  }
}
