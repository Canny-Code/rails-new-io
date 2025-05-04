import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["step", "nextStepTemplate", "container"]

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
    const currentStep = this.stepTargets.find(step => {
      const stepIdx = parseInt(step.dataset.stepIndex)

      return stepIdx === stepIndex
    })

    if (!currentStep) return

    // Mark current step as completed
    const currentStepCircle = currentStep.querySelector('.size-8')

    if (currentStepCircle) {
      currentStepCircle.innerHTML = ''


      currentStepCircle.classList.remove('border-2', 'border-gray-300', 'bg-white', 'group-hover:border-gray-400')
      currentStepCircle.classList.add('bg-[#008A05]')

      // Add checkmark
      currentStepCircle.innerHTML = `
        <svg class="size-5 text-white" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true" data-slot="icon">
          <path fill-rule="evenodd" d="M16.704 4.153a.75.75 0 0 1 .143 1.052l-8 10.5a.75.75 0 0 1-1.127.075l-4.5-4.5a.75.75 0 0 1 1.06-1.06l3.894 3.893 7.48-9.817a.75.75 0 0 1 1.05-.143Z" clip-rule="evenodd"></path>
        </svg>
      `
    }

    // Update the connecting line
    const connectingLine = currentStep.querySelector('.w-0\\.5')
    if (connectingLine) {
      connectingLine.classList.remove('bg-gray-300')
      connectingLine.classList.add('bg-[#008A05]')
    }

    // Find and activate next step
    const nextStep = this.stepTargets.find(step => {
      const nextStepIdx = parseInt(step.dataset.stepIndex)

      return nextStepIdx === stepIndex + 1
    })


    if (nextStep) {
      // Update next step to current
      const nextStepCircle = nextStep.querySelector('.size-8')

      if (stepIndex === this.stepTargets.length - 1) {
        const createIngredientButton = document.querySelector('#create-ingredient-button')
        if (createIngredientButton) {
          createIngredientButton.removeAttribute('disabled')
          createIngredientButton.removeAttribute('title')
          createIngredientButton.classList.remove('disabled:bg-[#99C49B]', 'disabled:cursor-not-allowed')
          createIngredientButton.classList.add('bg-[#008A05]', 'hover:bg-[#006D04]', 'active:bg-[#005503]')
        }
      }
      if (nextStepCircle) {
        nextStepCircle.innerHTML = '<span class="size-2.5 rounded-full bg-[#008A05]"></span>'
        nextStepCircle.classList.remove('border-gray-300')
        nextStepCircle.classList.add('border-[#008A05]')
      }

      nextStep.scrollIntoView({ behavior: 'smooth', block: 'nearest' })

      const currentStepInput = document.querySelector('input[name="current_step"]')
      if (currentStepInput) {
        currentStepInput.value = stepIndex + 1
      }
    }
  }
}
