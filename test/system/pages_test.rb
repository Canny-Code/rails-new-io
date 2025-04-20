require "application_system_test_case"
require_relative "./base_system_test_case"

class PagesTest < BaseSystemTestCase
  def setup
    super
    @user = users(:john)
  end

  test "visiting the basic setup page" do
    sign_in_as(@user)
    visit setup_recipes_path(slug: pages(:basic_setup).slug)

    assert_selector "h3", text: "Databases", wait: 5
    assert_equal setup_recipes_path(slug: pages(:basic_setup).slug), current_path
  end

  test "can navigate between pages" do
    sign_in_as(@user)
    visit setup_recipes_path(slug: pages(:basic_setup).slug)

    click_on "Your Custom Ingredients"

    assert_selector "h3", text: "No ingredients yet", wait: 5
    assert_equal setup_recipes_path(slug: pages(:custom_ingredients).slug), current_path
  end
end
