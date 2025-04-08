require "test_helper"

class IngredientUiDestroyerTest < ActiveSupport::TestCase
  setup do
    @ingredient = ingredients(:rails_authentication)
    @page = pages(:custom_ingredients)
  end

  def create_test_element(ingredient = @ingredient, sub_group = nil, group_behavior_type: "custom_ingredient_checkbox")
    group = sub_group&.group || @page.groups.create!(title: ingredient.category, behavior_type: group_behavior_type)
    sub_group ||= group.sub_groups.create!(title: "Default")

    # First try to find an existing checkbox for this ingredient
    checkbox = Element::CustomIngredientCheckbox.find_by(ingredient: ingredient)

    # Only create a new checkbox if one doesn't exist
    unless checkbox
      checkbox = Element::CustomIngredientCheckbox.create!(
        checked: false,
        default: false,
        ingredient: ingredient
      )
    end

    element = sub_group.elements.create!(
      label: ingredient.name,
      description: ingredient.description,
      position: 999,
      variant: checkbox,
      user: ingredient.created_by
    )

    [ group, sub_group, element, checkbox ]
  end

  test "deletes element when ingredient is destroyed" do
    group, sub_group, element, checkbox = create_test_element

    assert_difference -> { Element.count } => -1 do
      IngredientUiDestroyer.call(@ingredient)
    end

    assert_nil Element.find_by(id: element.id)
  end

  test "deletes sub_group when last element is removed" do
    group, sub_group, element, checkbox = create_test_element

    assert_difference -> { SubGroup.count } => -1 do
      IngredientUiDestroyer.call(@ingredient)
    end

    assert_nil SubGroup.find_by(id: sub_group.id)
  end

  test "deletes group when last sub_group is removed" do
    group, sub_group, element, checkbox = create_test_element

    assert_difference -> { Group.count } => -1 do
      IngredientUiDestroyer.call(@ingredient)
    end

    assert_nil Group.find_by(id: group.id)
  end

  test "does not delete sub_group if it has other elements" do
    group, sub_group, element, checkbox = create_test_element

    # Create another element with a different ingredient
    other_ingredient = ingredients(:basic)
    _, _, other_element, other_checkbox = create_test_element(other_ingredient, sub_group)

    assert_difference -> { Element.count } => -1 do
      assert_no_difference -> { SubGroup.count } do
        IngredientUiDestroyer.call(@ingredient)
      end
    end

    assert_nil Element.find_by(id: element.id)
    assert_not_nil Element.find_by(id: other_element.id)
  end

  test "does not delete group if it has other sub_groups" do
    group, sub_group, element, checkbox = create_test_element

    # Create another sub_group with a different element
    other_sub_group = group.sub_groups.create!(title: "Other")
    other_ingredient = ingredients(:basic)
    _, _, other_element, other_checkbox = create_test_element(other_ingredient, other_sub_group)

    assert_difference -> { Element.count } => -1 do
      assert_difference -> { SubGroup.count } => -1 do
        assert_no_difference -> { Group.count } do
          IngredientUiDestroyer.call(@ingredient)
        end
      end
    end

    assert_nil SubGroup.find_by(id: sub_group.id)
    assert_not_nil SubGroup.find_by(id: other_sub_group.id)
  end

  test "returns early if group not found" do
    @ingredient.update_column(:category, "NonExistentCategory")

    assert_no_difference -> { Element.count } do
      assert_no_difference -> { SubGroup.count } do
        assert_no_difference -> { Group.count } do
          IngredientUiDestroyer.call(@ingredient)
        end
      end
    end
  end

  test "returns early if sub_group not found" do
    group = @page.groups.create!(title: @ingredient.category)
    # Not creating the sub_group

    assert_no_difference -> { Element.count } do
      assert_no_difference -> { SubGroup.count } do
        assert_no_difference -> { Group.count } do
          IngredientUiDestroyer.call(@ingredient)
        end
      end
    end
  end

  test "returns early if element not found" do
    group = @page.groups.create!(title: @ingredient.category)
    sub_group = group.sub_groups.create!(title: "Default")
    # Not creating the element

    assert_no_difference -> { Element.count } do
      assert_no_difference -> { SubGroup.count } do
        assert_no_difference -> { Group.count } do
          IngredientUiDestroyer.call(@ingredient)
        end
      end
    end
  end

  test "destroys element and variant" do
    group, sub_group, element, checkbox = create_test_element

    assert_difference("Element.count", -1) do
      assert_difference("Element::CustomIngredientCheckbox.count", -1) do
        IngredientUiDestroyer.call(@ingredient)
      end
    end

    assert_not Element.exists?(element.id)
    assert_not Element::CustomIngredientCheckbox.exists?(checkbox.id)
  end

  test "destroys element and variant when multiple elements in sub_group" do
    group, sub_group, element, checkbox = create_test_element
    other_ingredient = ingredients(:basic)
    _, _, other_element, other_checkbox = create_test_element(other_ingredient, sub_group)

    assert_difference("Element.count", -1) do
      assert_difference("Element::CustomIngredientCheckbox.count", -1) do
        IngredientUiDestroyer.call(@ingredient)
      end
    end

    assert_not Element.exists?(element.id)
    assert_not Element::CustomIngredientCheckbox.exists?(checkbox.id)
    assert Element.exists?(other_element.id)
    assert Element::CustomIngredientCheckbox.exists?(other_checkbox.id)
  end

  test "destroys sub_group when last element" do
    group, sub_group, element, checkbox = create_test_element

    assert_difference("Element.count", -1) do
      assert_difference("Element::CustomIngredientCheckbox.count", -1) do
        assert_difference("SubGroup.count", -1) do
          IngredientUiDestroyer.call(@ingredient)
        end
      end
    end

    assert_not Element.exists?(element.id)
    assert_not Element::CustomIngredientCheckbox.exists?(checkbox.id)
    assert_not SubGroup.exists?(sub_group.id)
  end

  test "destroys group when last sub_group" do
    group, sub_group, element, checkbox = create_test_element
    other_ingredient = ingredients(:basic)

    # Create another element in a different sub_group
    other_sub_group = group.sub_groups.create!(title: "Other")
    _, _, other_element, other_checkbox = create_test_element(other_ingredient, other_sub_group)

    assert_difference("Element.count", -1) do
      assert_difference("Element::CustomIngredientCheckbox.count", -1) do
        assert_difference("SubGroup.count", -1) do
          assert_no_difference("Group.count") do
            IngredientUiDestroyer.call(@ingredient)
          end
        end
      end
    end

    assert_not Element.exists?(element.id)
    assert Element.exists?(other_element.id)
    assert_not Element::CustomIngredientCheckbox.exists?(checkbox.id)
    assert Element::CustomIngredientCheckbox.exists?(other_checkbox.id)
    assert_not SubGroup.exists?(sub_group.id)
    assert SubGroup.exists?(other_sub_group.id)
    assert Group.exists?(group.id)
  end

  test "does not destroy group when other sub_groups remain" do
    group, sub_group, element, checkbox = create_test_element

    # Create another sub_group (but no element in it)
    other_sub_group = group.sub_groups.create!(title: "Other")

    assert_difference("Element.count", -1) do
      assert_difference("Element::CustomIngredientCheckbox.count", -1) do
        assert_difference("SubGroup.count", -1) do
          assert_no_difference("Group.count") do
            IngredientUiDestroyer.call(@ingredient)
          end
        end
      end
    end

    assert_not Element.exists?(element.id)
    assert_not Element::CustomIngredientCheckbox.exists?(checkbox.id)
    assert_not SubGroup.exists?(sub_group.id)
    assert Group.exists?(group.id)
    assert SubGroup.exists?(other_sub_group.id)
  end
end
