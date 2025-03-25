import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["step", "nextStepTemplate"]

  static values = {
    steps: Object
  }

  connect() {
    Object.entries(this.stepsValue).forEach(([selector, config]) => {
      const field = document.querySelector(selector)
      if (field) {
        field.addEventListener('blur', () => this.checkFieldAndUpdateSteps(selector, config))
      }
    })
  }

  checkFieldAndUpdateSteps(selector, config) {
    const currentStepInput = document.querySelector('input[name="current_step"]')
    const currentStep = parseInt(currentStepInput.value)

    if (currentStep !== config.currentStep) return

    const field = document.querySelector(selector)

    if (field.value.trim() === config.expectedValue || config.expectedValue === "") {
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
