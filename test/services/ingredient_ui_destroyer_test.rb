require "test_helper"

class IngredientUiDestroyerTest < ActiveSupport::TestCase
  setup do
    @ingredient = ingredients(:rails_authentication)
    @page = pages(:custom_ingredients)
  end

  test "deletes element when ingredient is destroyed" do
    group = @page.groups.create!(title: @ingredient.category)
    sub_group = group.sub_groups.create!(title: "Default")

    # Create test element for our ingredient
    checkbox = Element::Checkbox.create!(
      checked: false,
      display_when: "checked"
    )

    element = sub_group.elements.create!(
      label: "Rails Authentication",
      description: @ingredient.description,
      position: 999,
      variant: checkbox
    )

    assert_difference -> { Element.count } => -1 do
      IngredientUiDestroyer.call(@ingredient)
    end

    assert_nil Element.find_by(id: element.id)
  end

  test "deletes sub_group when last element is removed" do
    # Create a new sub_group with a single element
    group = @page.groups.create!(title: @ingredient.category)
    sub_group = group.sub_groups.create!(title: "Default")
    checkbox = Element::Checkbox.create!(
      checked: false,
      display_when: "checked"
    )
    element = sub_group.elements.create!(
      label: "Rails Authentication",
      description: @ingredient.description,
      position: 999,
      variant: checkbox
    )

    assert_difference -> { SubGroup.count } => -1 do
      IngredientUiDestroyer.call(@ingredient)
    end

    assert_nil SubGroup.find_by(id: sub_group.id)
  end

  test "deletes group when last sub_group is removed" do
    # Create a new group with a single sub_group and element
    group = @page.groups.create!(title: @ingredient.category)
    sub_group = group.sub_groups.create!(title: "Default")
    checkbox = Element::Checkbox.create!(
      checked: false,
      display_when: "checked"
    )
    element = sub_group.elements.create!(
      label: "Rails Authentication",
      description: @ingredient.description,
      position: 999,
      variant: checkbox
    )

    assert_difference -> { Group.count } => -1 do
      IngredientUiDestroyer.call(@ingredient)
    end

    assert_nil Group.find_by(id: group.id)
  end

  test "does not delete sub_group if it has other elements" do
    # Create two elements in the same sub_group
    group = @page.groups.create!(title: @ingredient.category)
    sub_group = group.sub_groups.create!(title: "Default")

    checkbox1 = Element::Checkbox.create!(
      checked: false,
      display_when: "checked"
    )
    element1 = sub_group.elements.create!(
      label: "Rails Authentication",
      description: @ingredient.description,
      position: 998,
      variant: checkbox1
    )
    checkbox2 = Element::Checkbox.create!(
      checked: false,
      display_when: "checked"
    )
    element2 = sub_group.elements.create!(
      label: "Other Element",
      description: "Another element",
      position: 999,
      variant: checkbox2
    )

    assert_difference -> { Element.count } => -1 do
      assert_no_difference -> { SubGroup.count } do
        IngredientUiDestroyer.call(@ingredient)
      end
    end

    assert_nil Element.find_by(id: element1.id)
    assert_not_nil Element.find_by(id: element2.id)
  end

  test "does not delete group if it has other sub_groups" do
    # Create a group with two sub_groups
    group = @page.groups.create!(title: @ingredient.category)
    sub_group1 = group.sub_groups.create!(title: "Default")
    sub_group2 = group.sub_groups.create!(title: "Other")
    checkbox = Element::Checkbox.create!(
      checked: false,
      display_when: "checked"
    )
    element = sub_group1.elements.create!(
      label: "Rails Authentication",
      description: @ingredient.description,
      position: 999,
      variant: checkbox
    )

    assert_difference -> { Element.count } => -1 do
      assert_difference -> { SubGroup.count } => -1 do
        assert_no_difference -> { Group.count } do
          IngredientUiDestroyer.call(@ingredient)
        end
      end
    end

    assert_nil SubGroup.find_by(id: sub_group1.id)
    assert_not_nil SubGroup.find_by(id: sub_group2.id)
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
    # Not creating the "Default" sub_group

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

  test "raises error if custom ingredients page not found" do
    Page.find_by!(title: "Your Custom Ingredients").destroy

    assert_raises(ActiveRecord::RecordNotFound) do
      IngredientUiDestroyer.call(@ingredient)
    end
  end
end
