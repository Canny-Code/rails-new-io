import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["form", "field"]
  static values = {
    delay: { type: Number, default: 2000 }
  }

  connect() {
    this.timeout = null
  }

  fieldChanged() {
    if (this.timeout) {
      clearTimeout(this.timeout)
    }

    this.timeout = setTimeout(() => {
      this.save()
    }, this.delayValue)
  }

  save() {
    const form = this.formTarget
    const formData = new FormData(form)

    fetch(form.action, {
      method: form.method,
      body: formData,
      headers: {
        "Accept": "application/json",
        "X-Requested-With": "XMLHttpRequest"
      }
    })
  }
}
