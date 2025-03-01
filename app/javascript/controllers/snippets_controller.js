import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["container", "template"]

  connect() {
    // Initialize the controller
  }

  addSnippet(event) {
    event.preventDefault()

    // Clone the template and add it to the container
    const template = this.templateTarget.content.cloneNode(true)
    this.containerTarget.appendChild(template)

    // Focus the new snippet textarea
    const newTextarea = this.containerTarget.lastElementChild.querySelector('textarea')
    if (newTextarea) {
      newTextarea.focus()
    }
  }

  removeSnippet(event) {
    event.preventDefault()

    // Only allow removal if there's more than one snippet
    const snippets = this.containerTarget.querySelectorAll('div.relative')
    if (snippets.length > 1) {
      // Find the parent div and remove it
      const button = event.currentTarget
      const snippetContainer = button.closest('div.relative')
      snippetContainer.remove()
    }
  }
}
