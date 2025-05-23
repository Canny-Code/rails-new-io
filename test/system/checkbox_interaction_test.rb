# frozen_string_literal: true

require "application_system_test_case"
require_relative "./base_system_test_case"

class CheckboxInteractionTest < BaseSystemTestCase
  def setup
    super
    @user = users(:john)
  end

  test "updates rails-flags when checkbox is toggled" do
    sign_in_as(@user)
    visit setup_recipes_path(slug: pages(:basic_setup).slug)

    assert_current_path setup_recipes_path(slug: pages(:basic_setup).slug)
    assert_selector ".menu-card-row"

    # Uncheck any checked checkboxes that display when checked
    all("input[type='checkbox'][data-display-when='checked']").each do |checkbox|
      uncheck(checkbox[:id]) if checkbox.checked?
    end

    assert_selector "#rails-flags", visible: :all
    assert_no_text "--skip-docker"
    assert_no_text "--skip-action-mailer"

    # Now check the checkbox which should trigger the rails-flag-checkbox controller
    check "main-tab-mains-skip-docker"

    assert_text "--skip-docker"

    uncheck "main-tab-mains-skip-docker"
    assert_no_text "--skip-docker"
  end
end
