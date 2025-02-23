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
    // Listen for back/forward navigation:
    this.handlePopstate = this.handlePopstate.bind(this)
    window.addEventListener("popstate", this.handlePopstate)

    console.log("Page loaded. History length:", history.length)
    // On page load, sync the radio with the existing recipe_id (if any)
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

    console.log("PUSHING state. old=", window.location.href, "new=", newUrl.href)
    history.pushState({ recipeId }, "", newUrl.href)

    this.updateTerminalAndIngredients(radio)
  }

  // Called on popstate (i.e. Back/Forward) and also initial page load
  syncRadioFromUrl() {
    const recipeId = new URLSearchParams(window.location.search).get("recipe_id")

    // If a recipe_id was provided, check the matching radio
    if (recipeId) {
      const radio = this.radioTargets.find(r => r.value === recipeId)
      if (radio) {
        radio.checked = true
        this.updateTerminalAndIngredients(radio)
        // Fire a change event so other parts of your code can react
        radio.dispatchEvent(new Event('change', { bubbles: true }))
      }
    } else {
      // No recipe_id in URL => uncheck all or do nothing
      this.radioTargets.forEach(r => (r.checked = false))
    }
  }

  handlePopstate() {
    this.syncRadioFromUrl()
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
    document.getElementById('database-choice').textContent =
      flags.database ? flags.database[0] : ''
    document.getElementById('javascript-choice').textContent =
      flags.javascript ? flags.javascript[0] : ''
    document.getElementById('css-choice').textContent =
      flags.css ? flags.css[0] : ''

    // Filter out the special flags from 'other'
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
