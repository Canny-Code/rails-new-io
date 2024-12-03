import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    // Set initial height to prevent layout jump
    const height = this.element.offsetHeight
    this.element.style.height = `${height}px`
    this.element.style.overflow = 'hidden'

    setTimeout(() => {
      this.element.style.transition = "all 0.5s ease-in-out"
      this.element.style.opacity = 0
      this.element.style.height = '0px'
      this.element.style.marginTop = '0px'
      this.element.style.marginBottom = '0px'
      this.element.style.padding = '0px'
      
      setTimeout(() => {
        this.element.remove()
      }, 500)
    }, 2000)
  }
} 