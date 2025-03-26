import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["step", "nextStepTemplate"]

  static values = {
    steps: Object
  }

  connect() {
    if (document.readyState === 'loading') {
      document.addEventListener('DOMContentLoaded', () => this.initializeSteps())
    } else {
      this.initializeSteps()
    }
  }

  initializeSteps() {
    console.log("DEBUG: Starting initializeSteps")
    console.log("DEBUG: Document readyState:", document.readyState)
    console.log("DEBUG: Document body:", document.body)

    // Give a small delay to ensure everything is ready
    setTimeout(() => {
      Object.entries(this.stepsValue).forEach(([selector, config]) => {
        console.log("DEBUG: Trying to find selector:", selector)
        const field = document.querySelector(selector)
        console.log("DEBUG: Query result:", field)

        if (field) {
          if (selector.includes('CodeMirror')) {
            let attempts = 0
            const maxAttempts = 50 // 5 seconds total
            const checkCodeMirror = setInterval(() => {
              attempts++
              console.log("DEBUG: Checking CodeMirror initialization attempt:", attempts)

              if (field.CodeMirror) {
                console.log("DEBUG: CodeMirror initialized")
                field.CodeMirror.on('change', () => {
                  console.log("DEBUG: CodeMirror change event fired")
                  this.checkFieldAndUpdateSteps(selector, config)
                })
                clearInterval(checkCodeMirror)
                return
              }

              if (attempts >= maxAttempts) {
                console.log("DEBUG: Failed to initialize CodeMirror after", maxAttempts, "attempts")
                clearInterval(checkCodeMirror)
              }
            }, 100)
          } else {
            field.addEventListener('input', () => {
              console.log("DEBUG: Input event fired for selector:", selector)
              this.checkFieldAndUpdateSteps(selector, config)
            })
          }
        } else {
          console.log("DEBUG: No field found for selector:", selector)
        }
      })
    }, 100)
  }

  checkFieldAndUpdateSteps(selector, config) {
    const currentStepInput = document.querySelector('input[name="current_step"]')
    const currentStep = parseInt(currentStepInput.value)

    if (currentStep !== config.currentStep) return

    let field = document.querySelector(selector)
    let field_value = field?.value?.trim()

    if (selector.includes('CodeMirror')) {
      field = field.CodeMirror.getValue()
      field_value = field.trim()
    }

    if (field_value === config.expectedValue || config.expectedValue === "") {
      this.updateStep(config.currentStep)
    }
  }

  updateStep(stepIndex) {
    // Find the current step
    const currentStep = this.stepTargets.find(step =>
      parseInt(step.dataset.stepIndex) === stepIndex
    )

    const title = currentStep.querySelector('.text-sm.font-medium').textContent
    const description = currentStep.querySelector('.text-sm.text-gray-500').textContent

    const templateContent = this.nextStepTemplateTarget.content.cloneNode(true)
    const templateStep = templateContent.querySelector('[data-onboarding-sidebar-target="step"]')

    templateStep.querySelector('.text-sm.font-medium').textContent = title
    templateStep.querySelector('.text-sm.text-gray-500').textContent = description

    currentStep.innerHTML = templateStep.innerHTML

    this.stepTargets.forEach(step => {
      const stepIndex = parseInt(step.dataset.stepIndex)
      if (stepIndex === stepIndex + 1) {
        step.querySelector('.border-gray-300').classList.remove('border-gray-300')
        step.querySelector('.border-gray-300').classList.add('border-[#008A05]')
        step.querySelector('.bg-transparent').classList.remove('bg-transparent')
        step.querySelector('.bg-transparent').classList.add('bg-[#008A05]')
      }
    })

    const currentStepInput = document.querySelector('input[name="current_step"]')
    currentStepInput.value = stepIndex + 1
  }
}
