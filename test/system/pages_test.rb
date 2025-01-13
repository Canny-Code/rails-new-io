require "application_system_test_case"

class PagesTest < ApplicationSystemTestCase
  test "visiting the basic setup page" do
    visit setup_recipes_path(slug: pages(:basic_setup).slug)

    assert_selector "h1", text: "Create a New Rails App"
    assert_equal setup_recipes_path(slug: pages(:basic_setup).slug), current_path
  end

  test "can navigate between pages" do
    visit setup_recipes_path(slug: pages(:basic_setup).slug)

    click_on "Custom Ingredients"

    assert_selector "h1", text: "Custom Ingredients"
    assert_equal setup_recipes_path(slug: pages(:custom_ingredients).slug), current_path
  end

  test "can navigate between pages using tabs" do
    visit setup_recipes_path(slug: pages(:basic_setup).slug)

    find("#custom-ingredients-tab").click

    assert_selector "h1", text: "Custom Ingredients"
    assert_equal setup_recipes_path(slug: pages(:custom_ingredients).slug), current_path
  end

  test "can navigate between pages using keyboard shortcuts" do
    visit setup_recipes_path(slug: pages(:basic_setup).slug)

    find("body").send_keys("2")

    assert_selector "h1", text: "Custom Ingredients"
    assert_equal setup_recipes_path(slug: pages(:custom_ingredients).slug), current_path
  end

  test "can navigate between pages using keyboard shortcuts in reverse" do
    visit setup_recipes_path(slug: pages(:custom_ingredients).slug)

    find("body").send_keys("1")

    assert_selector "h1", text: "Basic Setup"
    assert_equal setup_recipes_path(slug: pages(:basic_setup).slug), current_path
  end
end
