import { Controller } from "@hotwired/stimulus"

const EMOJIS = ["🥗", "🥘", "🥙", "🌮", "🌯", "🥪", "🍕", "🥨", "🥯", "🥖", "🧀", "🥩", "🥓", "🍗", "🍖", "🌭", "🍔", "🍟", "🥫", "🍝", "🥣", "🥪", "🥨", "🍳", "🥚", "🧇", "🥞", "🧈", "🍞", "🥐", "🥨", "🥯", "🥖", "🧀"]

export default class extends Controller {
  static targets = ["radio"]

  connect() {
    // If we have a recipe_id in the URL, make sure the corresponding radio is selected
    const urlParams = new URLSearchParams(window.location.search)
    const recipeId = urlParams.get('recipe_id')
    if (recipeId) {
      const radio = this.radioTargets.find(r => r.value === recipeId)
      if (radio) {
        radio.checked = true
        this.updateTerminalAndIngredients(radio)
      }
    }
  }

  updateUrl(event) {
    const radio = event.target
    const recipeId = radio.value
    const url = new URL(window.location)
    url.searchParams.set('recipe_id', recipeId)
    history.pushState({}, '', url)

    this.updateTerminalAndIngredients(radio)
  }

  updateTerminalAndIngredients(radio) {
    const cliFlags = radio.dataset.cliFlags || ''
    const ingredients = (radio.dataset.ingredients || '').split(',').filter(Boolean)

    // Parse CLI flags
    const flags = {
      database: cliFlags.match(/-d\s+\S+/) || cliFlags.match(/--database=\S+/),
      javascript: cliFlags.match(/-j\s+\S+/) || cliFlags.match(/--javascript=\S+/),
      css: cliFlags.match(/-c\s+\S+/) || cliFlags.match(/--css=\S+/),
      other: cliFlags.match(/--\w+(?:-\w+)*(?:=\S+)?/g) || []
    }

    // Update terminal flags
    document.getElementById('database-choice').textContent = flags.database ? flags.database[0] : ''
    document.getElementById('javascript-choice').textContent = flags.javascript ? flags.javascript[0] : ''
    document.getElementById('css-choice').textContent = flags.css ? flags.css[0] : ''

    // Filter out the special flags from 'other'
    const otherFlags = flags.other.filter(flag =>
      !flag.startsWith('--database=') &&
      !flag.startsWith('--javascript=') &&
      !flag.startsWith('--css=')
    )
    document.getElementById('rails-flags').textContent = otherFlags.join(' ')

    // Update ingredients container
    const customIngredientsContainer = document.getElementById('custom-ingredients-container')
    const headingContainer = document.querySelector('[data-custom-ingredients-target="heading"]')

    if (ingredients.length > 0) {
      headingContainer.classList.remove('max-h-0', 'opacity-0')
      headingContainer.classList.add('max-h-24', 'opacity-100')

      customIngredientsContainer.innerHTML = ingredients.map(ingredient => {
        const emoji = EMOJIS[Math.floor(Math.random() * EMOJIS.length)]
        return `
          <div class="inline-flex items-center px-2.5 py-0.5 rounded-md text-sm font-medium bg-[#dfe8f0] text-gray-800 shadow-sm border border-[#30353A]/20" data-value="${ingredient}">
            <span class="mr-1.5">${emoji}</span>${ingredient}
          </div>
        `
      }).join('')
    } else {
      headingContainer.classList.remove('max-h-24', 'opacity-100')
      headingContainer.classList.add('max-h-0', 'opacity-0')
      customIngredientsContainer.innerHTML = ''
    }
  }
}
