import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["step", "nextStepTemplate"]

  connect() {
    const categoryField = document.querySelector('input[name="ingredient[category]"]')
    categoryField.addEventListener('focus', () => this.checkNameFieldAndUpdateSteps())

    const descriptionField = document.querySelector('textarea[name="ingredient[description]"]')
    descriptionField.addEventListener('focus', () => this.checkCategoryFieldAndUpdateSteps())
  }

  async checkNameFieldAndUpdateSteps() {
    const currentStepInput = document.querySelector('input[name="current_step"]')
    if (parseInt(currentStepInput.value) !== 1) return

    const nameField = document.querySelector('input[name="ingredient[name]"]')

    if (nameField.value.trim() === 'Rails authentication') {
      this.updateStep(1)
    }
  }

  async checkCategoryFieldAndUpdateSteps() {
    const currentStepInput = document.querySelector('input[name="current_step"]')
    if (parseInt(currentStepInput.value) !== 2) return

    const categoryField = document.querySelector('input[name="ingredient[category]"]')

    if (categoryField.value.trim() === 'Authentication') {
      this.updateStep(2)
    }
  }

  updateStep(stepIndex) {
    // Find the current step
    const currentStep = this.stepTargets.find(step =>
      parseInt(step.dataset.stepIndex) === stepIndex
    )

    if (!currentStep) return

    // Get the template content
    const templateContent = this.nextStepTemplateTarget.content.cloneNode(true)
    const templateStep = templateContent.querySelector('[data-onboarding-sidebar-target="step"]')

    // Update the current step with the template content
    currentStep.innerHTML = templateStep.innerHTML

    // Update the current step indicator
    this.stepTargets.forEach(step => {
      const stepIndex = parseInt(step.dataset.stepIndex)
      if (stepIndex === stepIndex + 1) {
        step.querySelector('.border-gray-300').classList.remove('border-gray-300')
        step.querySelector('.border-gray-300').classList.add('border-[#008A05]')
        step.querySelector('.bg-transparent').classList.remove('bg-transparent')
        step.querySelector('.bg-transparent').classList.add('bg-[#008A05]')
      }
    })

    // Update the hidden form's current step
    const currentStepInput = document.querySelector('input[name="current_step"]')
    currentStepInput.value = stepIndex + 1
  }
}
