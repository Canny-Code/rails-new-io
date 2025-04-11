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

  disconnect() {
    if (this.resizeObservers) {
      this.resizeObservers.forEach(observer => observer.disconnect())
      this.resizeObservers = []
    }
    this.initialized = false
  }

  initializeSteps() {
    this.initialized = true
    this.resizeObservers = []

    setTimeout(() => {
      Object.entries(this.stepsValue).forEach(([selector, config]) => {
        if (selector.startsWith('appear:')) {
          const targetSelector = selector.replace('appear:', '')

          const observer = new ResizeObserver((entries) => {
            entries.forEach(entry => {
              const targetElement = entry.target
              const computedStyle = getComputedStyle(targetElement)

              const isVisible = computedStyle.display !== 'none' && targetElement.offsetParent !== null
              if (isVisible) {
                this.updateStep(config.currentStep)
              }
            })
          })

          document.querySelectorAll(targetSelector).forEach(element => observer.observe(element))

          this.resizeObservers.push(observer)
        } else if (selector.startsWith('click:')) {
          const targetSelector = selector.replace('click:', '')

          const field = document.querySelector(targetSelector)
          if (field) {
            field.addEventListener('click', () => {
              this.updateStep(config.currentStep)
            })
          }
        } else if (selector.includes('CodeMirror')) {
          let attempts = 0
          const maxAttempts = 50 // 5 seconds total
          const checkCodeMirror = setInterval(() => {
            attempts++

            const field = document.querySelector(selector)
            if (!field) {
              if (attempts >= maxAttempts) {
                clearInterval(checkCodeMirror)
              }
              return
            }

            if (field.CodeMirror) {
              field.CodeMirror.on('change', () => {
                this.checkFieldAndUpdateSteps(selector, config)
              })
              clearInterval(checkCodeMirror)
              return
            }

            if (attempts >= maxAttempts) {
              clearInterval(checkCodeMirror)
            }
          }, 100)
        } else {
          const field = document.querySelector(selector)
          if (field) {
            field.addEventListener('input', () => {
              this.checkFieldAndUpdateSteps(selector, config)
            })
          }
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
    const description = currentStep.querySelector('.text-sm.text-gray-500').innerHTML

    const templateContent = this.nextStepTemplateTarget.content.cloneNode(true)
    const templateStep = templateContent.querySelector('[data-onboarding-sidebar-target="step"]')

    templateStep.querySelector('.text-sm.font-medium').textContent = title
    templateStep.querySelector('.text-sm.text-gray-500').innerHTML = description

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
