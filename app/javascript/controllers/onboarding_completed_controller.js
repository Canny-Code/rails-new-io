import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["explanation"]

  connect() {
    const urlParams = new URLSearchParams(window.location.search)
    const onboardingStep = urlParams.get('onboarding_step')

    if (onboardingStep) {
      this.element.dataset.onboardingStep = onboardingStep
    }
  }
}
