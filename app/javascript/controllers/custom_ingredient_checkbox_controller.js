import { Controller } from "@hotwired/stimulus"

const EMOJIS = ["🥗", "🥘", "🥙", "🌮", "🌯", "🥪", "🍕", "🥨", "🥯", "🥖", "🧀", "🥩", "🥓", "🍗", "🍖", "🌭", "🍔", "🍟", "🥫", "🍝", "🥣", "🥪", "🥨", "🍳", "🥚", "🧇", "🥞", "🧈", "🍞", "🥐", "🥨", "🥯", "🥖", "🧀"]

// Handles the Custom Ingredient checkboxes in the UI
export default class extends Controller {
  static values = {
    generatedOutputOutlet: String
  }

  connect() {
    this.groupElement = this.element.closest('ul')
    if (!this.groupElement) return
    this.pillsContainer = document.getElementById('custom-ingredients-container')
    this.selectedIngredients = new Set()
    this.update()
  }

  update(event) {
    if (!event) return

    const checkbox = event.target
    const value = checkbox.dataset.commandOutput
    const ingredientId = checkbox.dataset.ingredientId
    const label = checkbox.closest('label').querySelector('.menu-card-row-title').textContent.trim()

    if (checkbox.checked) {
      this.selectedIngredients.add(value)
      this.addPill(value, label)
      this.addHiddenInput(ingredientId)
    } else {
      this.selectedIngredients.delete(value)
      this.removePill(value)
      this.removeHiddenInput(ingredientId)
    }

    // Update command line output
    const outputElement = document.getElementById('custom_ingredients')
    if (outputElement) {
      outputElement.textContent = Array.from(this.selectedIngredients).join(" ")
    }
  }

  addPill(value, label) {
    if (this.pillsContainer.querySelector(`[data-value="${value}"]`)) return

    const emoji = EMOJIS[Math.floor(Math.random() * EMOJIS.length)]
    const pill = document.createElement('div')
    pill.className = 'inline-flex items-center px-2.5 py-0.5 rounded-md text-sm font-medium bg-[#dfe8f0] text-gray-800 shadow-sm border border-[#30353A]/20'
    pill.dataset.value = value
    pill.innerHTML = `<span class="mr-1.5">${emoji}</span>${label}`
    this.pillsContainer.appendChild(pill)
  }

  removePill(value) {
    const pill = this.pillsContainer.querySelector(`[data-value="${value}"]`)
    if (pill) {
      pill.remove()
    }
  }

  addHiddenInput(ingredientId) {
    const form = document.querySelector('form#new-recipe')

    const input = document.createElement('input')
    input.type = 'hidden'
    input.name = 'recipe[ingredient_ids][]'
    input.value = ingredientId
    input.dataset.ingredientId = ingredientId
    form.appendChild(input)
  }

  removeHiddenInput(ingredientId) {
    const form = document.querySelector('form#new-recipe')

    const input = form.querySelector(`input[data-ingredient-id="${ingredientId}"]`)
    if (input) {
      input.remove()
    }
  }
}
