# == Schema Information
#
# Table name: element_custom_ingredient_checkboxes
#
#  id            :integer          not null, primary key
#  checked       :boolean
#  default       :boolean
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  ingredient_id :integer          not null
#
# Indexes
#
#  index_element_custom_ingredient_checkboxes_on_ingredient_id   (ingredient_id)
#  index_element_custom_ingredient_checkboxes_unique_ingredient  (ingredient_id) UNIQUE
#  unique_ingredient_checkbox                                    (ingredient_id) UNIQUE
#
# Foreign Keys
#
#  ingredient_id  (ingredient_id => ingredients.id)
#
require "test_helper"

class Element::CustomIngredientCheckboxTest < ActiveSupport::TestCase
  test "checkbox is always displayed" do
    checkbox = Element::CustomIngredientCheckbox.new
    assert checkbox.displayed?
  end

  test "prevents direct destruction when element exists" do
    ingredient = ingredients(:api_setup)
    checkbox = Element::CustomIngredientCheckbox.create!(ingredient: ingredient)

    # Create a sub_group and element with required attributes
    page = pages(:custom_ingredients)
    group = page.groups.create!(title: "Test Group", behavior_type: "custom_ingredient_checkbox")
    sub_group = group.sub_groups.create!(title: "Default")

    element = Element.create!(
      label: "Test Element",
      description: "Test Description",
      variant: checkbox,
      sub_group: sub_group,
      user: users(:john)
    )

    error = assert_raises(ActiveRecord::RecordNotDestroyed) do
      checkbox.destroy
    end

    assert_includes error.message, "must be destroyed through its element"
    assert Element::CustomIngredientCheckbox.exists?(checkbox.id)
  end

  test "allows destruction when element is already destroyed" do
    ingredient = ingredients(:api_setup)
    checkbox = Element::CustomIngredientCheckbox.create!(ingredient: ingredient)

    # Create a sub_group and element with required attributes
    page = pages(:custom_ingredients)
    group = page.groups.create!(title: "Test Group", behavior_type: "custom_ingredient_checkbox")
    sub_group = group.sub_groups.create!(title: "Default")

    element = Element.create!(
      label: "Test Element",
      description: "Test Description",
      variant: checkbox,
      sub_group: sub_group,
      user: users(:john)
    )

    element.destroy

    assert_nothing_raised do
      checkbox.destroy
    end

    assert_not Element::CustomIngredientCheckbox.exists?(checkbox.id)
  end

  test "allows destruction when no element exists" do
    # Create a new ingredient to avoid uniqueness constraint
    ingredient = Ingredient.create!(
      name: "Test Ingredient",
      description: "Test Description",
      template_content: "# Test template",
      category: "Testing",
      sub_category: "Default",
      created_by: users(:john),
      page_id: pages(:custom_ingredients).id
    )

    checkbox = Element::CustomIngredientCheckbox.create!(ingredient: ingredient)

    assert_nothing_raised do
      checkbox.destroy
    end

    assert_not Element::CustomIngredientCheckbox.exists?(checkbox.id)
  end
end
