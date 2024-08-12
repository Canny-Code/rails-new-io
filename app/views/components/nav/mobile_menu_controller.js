import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    'hamburgerMenuOpen',
    'hamburgerMenuClose',
    'mobileNavigationDropdown'
  ]

  connect() {
    console.log('============ waa ==================')
  }

  toggleHamburger() {
    this.hamburgerMenuOpenTarget.classList.add('hidden')
    this.hamburgerMenuCloseTarget.classList.remove('hidden')
    this.mobileNavigationDropdownTarget.classList.remove('hidden')
  }

  toggleClose() {
    this.hamburgerMenuOpenTarget.classList.remove('hidden')
    this.hamburgerMenuCloseTarget.classList.add('hidden')
    this.mobileNavigationDropdownTarget.classList.add('hidden')
  }
}
