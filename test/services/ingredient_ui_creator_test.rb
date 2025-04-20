require "test_helper"
require_relative "../../app/services/ingredient_ui_creator"

class IngredientUiCreatorTest < ActiveSupport::TestCase
  setup do
    @ingredient = ingredients(:rails_authentication)
    @page = pages(:custom_ingredients)
  end

  test "raises IngredientUiCreationError with error details when page not found" do
    error = assert_raises(IngredientUiCreationError) do
      IngredientUiCreator.call(@ingredient, page_title: "Non-existent Page")
    end

    assert_includes error.message, "Unexpected error creating ingredient UI"
    assert_includes error.message, "Couldn't find Page"
  end

  test "raises IngredientUiCreationError with error details when group creation fails" do
    # Force group creation to fail by making the title nil
    @ingredient.stubs(:category).returns(nil)

    error = assert_raises(IngredientUiCreationError) do
      IngredientUiCreator.call(@ingredient)
    end

    assert_includes error.message, "Unexpected error creating ingredient UI"
    assert_includes error.message, "Validation failed"
  end

  test "creates element in existing group and sub_group" do
    # Create a new ingredient for testing to avoid conflicts with fixtures
    test_ingredient = Ingredient.create!(
      name: "Test Ingredient",
      description: "Test Description",
      template_content: "# Test template",
      category: "Testing",
      sub_category: "Default",
      created_by: @ingredient.created_by,
      page_id: @page.id
    )

    # Create the group and sub_group first
    group = @page.groups.create!(
      title: test_ingredient.category,
      behavior_type: "custom_ingredient_checkbox",
      position: 0
    )
    sub_group = group.sub_groups.create!(
      title: test_ingredient.sub_category,
      position: 0
    )

    # Create a new ingredient for the initial element to avoid conflicts
    initial_ingredient = Ingredient.create!(
      name: "Initial Test Ingredient",
      description: "Initial Description",
      template_content: "# Test template",
      category: test_ingredient.category,
      sub_category: test_ingredient.sub_category,
      created_by: test_ingredient.created_by,
      page_id: @page.id
    )

    # Create an initial element to test position increment
    initial_element = sub_group.elements.create!(
      user: test_ingredient.created_by,
      label: "Initial Element",
      description: "Initial Description",
      position: 0,
      variant: Element::CustomIngredientCheckbox.create!(
        checked: false,
        default: false,
        ingredient: initial_ingredient
      )
    )

    # Now create our test element
    IngredientUiCreator.call(test_ingredient)

    # Verify the element was created with correct attributes
    element = sub_group.elements.find_by(label: test_ingredient.name)
    assert_not_nil element
    assert_equal test_ingredient.description, element.description
    assert_equal 1, element.position  # Should be after the initial element
    assert_equal test_ingredient.created_by, element.user
    assert_equal "Element::CustomIngredientCheckbox", element.variant_type

    # Verify the variant was created correctly
    variant = element.variant
    assert_not_nil variant
    assert_equal test_ingredient, variant.ingredient
    assert_equal false, variant.checked
    assert_equal false, variant.default

    # Clean up
    initial_ingredient.destroy
    test_ingredient.destroy
  end
end
