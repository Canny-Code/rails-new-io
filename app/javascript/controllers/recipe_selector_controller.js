import { Controller } from "@hotwired/stimulus"

const EMOJIS = [
  "🥗", "🥘", "🥙", "🌮", "🌯", "🥪", "🍕",
  "🥨", "🥯", "🥖", "🧀", "🥩", "🥓", "🍗",
  "🍖", "🌭", "🍔", "🍟", "🥫", "🍝", "🥣",
  "🥪", "🥨", "🍳", "🥚", "🧇", "🥞", "🧈",
  "🍞", "🥐", "🥨", "🥯", "🥖", "🧀"
]

export default class extends Controller {
  static targets = ["radio"]

  connect() {
    if (this.element.id === "recipe-rehydration-radio") {
      this.updateTerminalAndIngredients(this.element)
      return
    }

    // Listen for back/forward navigation:
    this.handlePopstate = this.handlePopstate.bind(this)
    this.lastSelectedRadio = null;
    window.addEventListener("popstate", this.handlePopstate)
    this.syncRadioFromUrl()
  }

  disconnect() {
    window.removeEventListener("popstate", this.handlePopstate)
  }

  // Called when a radio is clicked
  updateUrl(event) {
    const radio = event.target
    const recipeId = radio.value

    const newUrl = new URL(window.location.href)
    newUrl.searchParams.set("recipe_id", recipeId)

    // If the URL didn't actually change, skip
    if (newUrl.href === window.location.href) {
      return
    }

    history.pushState({ recipeId }, "", newUrl.href)

    if (this.lastSelectedRadio && this.lastSelectedRadio !== radio) {
      this.lastSelectedRadio.blur()
    }

    this.lastSelectedRadio = radio

    this.updateTerminalAndIngredients(radio)
  }

  syncRadioFromUrl() {
    if(document.getElementById('recipe-rehydration-radio')) return;
    const recipeId = new URLSearchParams(window.location.search).get("recipe_id")

    if (recipeId) {
      const radio = this.radioTargets.find(r => r.value === recipeId)

      if (this.lastSelectedRadio && this.lastSelectedRadio !== radio) {
        this.lastSelectedRadio.blur()
      }

      if (radio) {
        radio.checked = true
        this.updateTerminalAndIngredients(radio)
        this.lastSelectedRadio = radio

        radio.dispatchEvent(new Event('change', { bubbles: true }))
      }
    } else {
      this.radioTargets.forEach(r => (r.checked = false))
      if (this.lastSelectedRadio) this.lastSelectedRadio.blur()
      this.lastSelectedRadio = null
    }
  }

  handlePopstate() {
    this.syncRadioFromUrl()
  }

  updateTerminalAndIngredients(radio) {
    const cliFlags = radio.dataset.cliFlags || ''
    const ingredients = (radio.dataset.ingredients || '').split(',').filter(Boolean)
    const flags = {
      database: cliFlags.match(/-d\s+\S+/) || cliFlags.match(/--database=\S+/),
      javascript: cliFlags.match(/-j\s+\S+/) || cliFlags.match(/--javascript=\S+/),
      css: cliFlags.match(/-c\s+\S+/) || cliFlags.match(/--css=\S+/),
      other: cliFlags.match(/--\w+(?:-\w+)*(?:=\S+)?/g) || []
    }

    // Update terminal flags
    document.getElementById('database-choice').textContent =
      flags.database ? flags.database[0] : ''
    document.getElementById('javascript-choice').textContent =
      flags.javascript ? flags.javascript[0] : ''
    document.getElementById('css-choice').textContent =
      flags.css ? flags.css[0] : ''

    const otherFlags = flags.other.filter(flag =>
      !flag.startsWith('--database=') &&
      !flag.startsWith('--javascript=') &&
      !flag.startsWith('--css=')
    )
    document.getElementById('rails-flags').textContent = otherFlags.join(' ')

    // Update ingredients
    const customIngredientsContainer = document.getElementById('custom-ingredients-container')
    const headingContainer = document.querySelector('[data-custom-ingredients-target="heading"]')

    if (ingredients.length > 0) {
      headingContainer.classList.remove('max-h-0', 'opacity-0')
      headingContainer.classList.add('max-h-24', 'opacity-100')

      customIngredientsContainer.innerHTML = ingredients.map(ingredient => {
        const emoji = EMOJIS[Math.floor(Math.random() * EMOJIS.length)]
        return `
          <div
            class="inline-flex items-center px-2.5 py-0.5 rounded-md text-sm font-medium bg-[#dfe8f0] text-gray-800 shadow-sm border border-[#30353A]/20"
            data-value="${ingredient}"
          >
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
