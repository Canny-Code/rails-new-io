require "application_system_test_case"

class PagesTest < ApplicationSystemTestCase
  test "switches between tabs and persists element state" do
    visit page_path(pages(:basic_setup))

    # Verify initial state
    assert_selector "h3", text: "Databases"
    assert_selector ".tab-active", text: "Basic Setup"
    assert_equal page_path(pages(:basic_setup)), current_path

    # Verify SQLite3 is selected by default
    assert find("#main-tab-database-choice-sqlite3").checked?

    # Choose PostgreSQL
    find("input[type='radio'][id='main-tab-database-choice-postgresql']").click

    # Verify the selection was made
    assert find("#main-tab-database-choice-postgresql").checked?
    assert_not find("#main-tab-database-choice-sqlite3").checked?

    # Click the Custom Ingredients tab
    find("#your-custom-ingredients-tab").click

    # Verify URL and content changed
    assert_equal page_path(pages(:custom_ingredients)), current_path
    assert_selector "h3", text: "Your Custom Ingredients"
    assert_selector ".tab-active", text: "Your Custom Ingredients"
    assert_selector ".tab-inactive", text: "Basic Setup"

    # Go back using browser history
    go_back

    # Verify we're back on the original page with state preserved
    assert_equal page_path(pages(:basic_setup)), current_path
    assert_selector "h3", text: "Databases"
    assert_selector ".tab-active", text: "Basic Setup"
    assert_selector ".tab-inactive", text: "Your Custom Ingredients"

    # Verify PostgreSQL selection was preserved
    assert find("#main-tab-database-choice-postgresql").checked?
    assert_not find("#main-tab-database-choice-sqlite3").checked?

    # Go forward using browser history
    go_forward

    # Verify we're back on the custom ingredients page
    assert_equal page_path(pages(:custom_ingredients)), current_path
    assert_selector "h3", text: "Your Custom Ingredients"
    assert_selector ".tab-active", text: "Your Custom Ingredients"
    assert_selector ".tab-inactive", text: "Basic Setup"

    # Go back to basic setup using tab click
    find("#basic-setup-tab").click

    # Verify URL and content changed
    assert_equal page_path(pages(:basic_setup)), current_path
    assert_selector "h3", text: "Databases"
    assert_selector ".tab-active", text: "Basic Setup"

    # Verify PostgreSQL selection was still preserved
    assert find("#main-tab-database-choice-postgresql").checked?
    assert_not find("#main-tab-database-choice-sqlite3").checked?
  end
end
