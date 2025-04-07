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
    this.headingElement = document.querySelector('[data-custom-ingredients-target="heading"]')
    this.selectedIngredients = new Set()
    this.update()
    this.toggleHeadingVisibility()

    const form = document.querySelector('form#new-recipe')
    if (form) {
      form.addEventListener('submit', this.validateBeforeSubmit.bind(this))
    }
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

    this.toggleHeadingVisibility()

    // Update command line output
    const outputElement = document.getElementById('custom_ingredients')
    if (outputElement) {
      outputElement.textContent = Array.from(this.selectedIngredients).join(" ")
    }
  }

  toggleHeadingVisibility() {
    if (this.headingElement) {
      if (this.pillsContainer.children.length > 0) {
        this.headingElement.classList.remove('max-h-0', 'opacity-0')
        this.headingElement.classList.add('max-h-24', 'opacity-100')
      } else {
        this.headingElement.classList.remove('max-h-24', 'opacity-100')
        this.headingElement.classList.add('max-h-0', 'opacity-0')
      }
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

    // Check if field already exists
    const existingField = form.querySelector(`input[data-ingredient-id="${ingredientId}"]`)
    if (existingField) {
      return // Field already exists, do nothing
    }

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

  validateBeforeSubmit(event) {
    const form = event.target
    const checkedBoxes = document.querySelectorAll('input[type="checkbox"][data-controller="custom-ingredient-checkbox"]:checked')
    const hiddenFields = form.querySelectorAll('input[name="recipe[ingredient_ids][]"]')

    // Remove orphaned fields
    hiddenFields.forEach(field => {
      const id = field.dataset.ingredientId
      if (!document.querySelector(`input[type="checkbox"][data-ingredient-id="${id}"]:checked`)) {
        field.remove()
      }
    })

    // Add missing fields
    checkedBoxes.forEach(box => {
      const id = box.dataset.elementId
      if (!form.querySelector(`input[data-ingredient-id="${id}"]`)) {
        this.addHiddenInput(id)
      }
    })
  }
}
