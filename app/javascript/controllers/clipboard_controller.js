import { Controller } from "@hotwired/stimulus"
import tippy from 'tippy.js'
import 'tippy.js/dist/tippy.css'

export default class extends Controller {
  static values = {
    text: String
  }

  connect() {
    this.tooltip = tippy(this.element, {
      content: 'Copy',
      trigger: 'mouseenter',
      duration: [200, 1800],
      placement: 'top',
      hideOnClick: true
    })

    this.copyTooltip = tippy(this.element, {
      content: 'Copied!',
      trigger: 'manual',
      duration: [200, 800],
      placement: 'top'
    })
  }

  copy() {
    navigator.clipboard.writeText(this.textValue)
    this.tooltip.hide()
    this.copyTooltip.show()

    setTimeout(() => {
      this.copyTooltip.hide()
      this.tooltip.enable()
    }, 1000)
  }

  disconnect() {
    this.tooltip.destroy()
    this.copyTooltip.destroy()
  }
}
