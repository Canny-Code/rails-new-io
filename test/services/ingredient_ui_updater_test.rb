require "test_helper"

class IngredientUiUpdaterTest < ActiveSupport::TestCase
  setup do
    @ingredient = ingredients(:rails_authentication)
    @updater = IngredientUiUpdater.new(@ingredient)

    # Mock repository operations
    DataRepositoryService.any_instance.stubs(:push_app_files).returns(true)
    DataRepositoryService.any_instance.stubs(:initialize_repository).returns(true)

    # Clean up any existing test data
    # Page.where(title: "Your Custom Ingredients").destroy_all  # Remove this line as we'll use the fixture

    # Create a fresh copy of the ingredient to avoid frozen record issues
    fixture_ingredient = ingredients(:rails_authentication).dup
    @ingredient = Ingredient.create!(
      name: "Test Ingredient #{SecureRandom.hex(8)}",
      description: fixture_ingredient.description,
      template_content: fixture_ingredient.template_content,
      category: fixture_ingredient.category,
      created_by: users(:john)  # Use the user fixture directly since it's just a reference
    )

    @page = pages(:custom_ingredients)  # Use the fixture instead of creating a new page
    @group = @page.groups.create!(title: @ingredient.category, behavior_type: "custom_ingredient_checkbox")
    @sub_group = @group.sub_groups.create!(title: "Default")

    # Create the variant first
    @variant = Element::CustomIngredientCheckbox.create!(
      ingredient: @ingredient,
      checked: false,
      default: false
    )

    # Then create the element with the variant
    @element = Element.create!(
      label: @ingredient.name,
      description: @ingredient.description,
      variant_type: "Element::CustomIngredientCheckbox",
      variant_id: @variant.id,
      sub_group: @sub_group,
      user: @ingredient.created_by
    )
  end

  teardown do
    # Clean up any created records that aren't in fixtures
    Element.where(sub_group_id: [ @sub_group&.id ]).destroy_all
    Element::CustomIngredientCheckbox.where(ingredient_id: [ @ingredient&.id ]).destroy_all
    SubGroup.where(id: @sub_group&.id).destroy_all
    Group.where(id: @group&.id).destroy_all
    @ingredient&.destroy
    # Page.where(title: "Your Custom Ingredients").destroy_all  # Remove this line as we're using the fixture
  end

  test "updates element attributes when ingredient is updated" do
    new_name = "Updated Auth #{SecureRandom.hex(8)}"
    @ingredient.update!(
      name: new_name,
      description: "New description"
    )

    IngredientUiUpdater.call(@ingredient)

    @element.reload
    assert_equal new_name, @element.label
    assert_equal "New description", @element.description
  end

  test "moves element to new group when category changes" do
    new_category = "security"
    old_group_id = @group.id
    old_sub_group_id = @sub_group.id

    @ingredient.update!(category: new_category)
    IngredientUiUpdater.call(@ingredient)

    @element.reload
    assert_equal new_category, @element.sub_group.group.title
    assert_equal "Default", @element.sub_group.title

    # Verify old group and sub_group were cleaned up
    assert_raises(ActiveRecord::RecordNotFound) { Group.find(old_group_id) }
    assert_raises(ActiveRecord::RecordNotFound) { SubGroup.find(old_sub_group_id) }
  end

  test "cleans up empty groups and sub_groups after moving element" do
    old_group_id = @group.id
    old_sub_group_id = @sub_group.id

    @ingredient.update!(category: "security")
    IngredientUiUpdater.call(@ingredient)

    assert_raises(ActiveRecord::RecordNotFound) { SubGroup.find(old_sub_group_id) }
    assert_raises(ActiveRecord::RecordNotFound) { Group.find(old_group_id) }
  end

  test "does not clean up groups that still have elements" do
    other_ingredient = Ingredient.create!(
      name: "Basic Setup #{SecureRandom.hex(8)}",
      description: "A basic setup",
      template_content: "template",
      category: @ingredient.category,
      created_by: @ingredient.created_by
    )

    other_variant = Element::CustomIngredientCheckbox.create!(
      ingredient: other_ingredient,
      checked: false,
      default: false
    )

    # Then create the element with the variant
    other_element = Element.create!(
      label: other_ingredient.name,
      description: other_ingredient.description,
      variant_type: "Element::CustomIngredientCheckbox",
      variant_id: other_variant.id,
      sub_group: @sub_group,
      user: other_ingredient.created_by
    )

    old_group_id = @group.id
    old_sub_group_id = @sub_group.id

    @ingredient.update!(category: "security")
    IngredientUiUpdater.call(@ingredient)

    # Verify old group and sub_group still exist
    assert_nothing_raised { Group.find(old_group_id) }
    assert_nothing_raised { SubGroup.find(old_sub_group_id) }

    # Verify only one element remains in old sub_group
    old_sub_group = SubGroup.find(old_sub_group_id)
    assert_equal 1, old_sub_group.elements.count
    assert_equal other_element, old_sub_group.elements.first

    # Clean up
    other_element.destroy
    other_variant.destroy
    other_ingredient.destroy
  end

  test "handles non-existent page gracefully" do
    # Delete in correct order: elements -> sub_groups -> groups
    Element.where(sub_group_id: @sub_group.id).delete_all
    SubGroup.where(group_id: @group.id).delete_all
    Group.where(page_id: @page.id).delete_all
    # Don't delete the page as it's a fixture
    # Page.where(id: @page.id).delete_all

    assert_nothing_raised do
      IngredientUiUpdater.call(@ingredient)
    end
  end

  test "handles non-existent group gracefully" do
    # Delete in correct order: elements -> sub_groups -> group
    Element.where(sub_group_id: @sub_group.id).delete_all
    SubGroup.where(group_id: @group.id).delete_all
    Group.where(id: @group.id).delete_all

    assert_nothing_raised do
      IngredientUiUpdater.call(@ingredient)
    end
  end

  test "handles non-existent sub_group gracefully" do
    # Delete in correct order: elements -> sub_group
    Element.where(sub_group_id: @sub_group.id).delete_all
    SubGroup.where(id: @sub_group.id).delete_all

    assert_nothing_raised do
      IngredientUiUpdater.call(@ingredient)
    end
  end

  test "handles non-existent element gracefully" do
    # Delete element and its variant
    Element.where(id: @element.id).delete_all
    Element::CustomIngredientCheckbox.where(id: @variant.id).delete_all

    assert_nothing_raised do
      IngredientUiUpdater.call(@ingredient)
    end
  end

  test "preserves sub_group title when moving element between groups" do
    # Create a sub_group with a different title
    custom_sub_group = @group.sub_groups.create!(title: "Advanced Options")

    # Move our element to the custom sub_group
    @element.update!(sub_group: custom_sub_group)

    # The original @sub_group should be cleaned up since it's now empty
    @sub_group.destroy!

    # Change category to trigger move
    new_category = "security"
    @ingredient.update!(category: new_category)

    IngredientUiUpdater.call(@ingredient)

    # Verify element moved to new group but kept its sub_group title
    @element.reload
    assert_equal new_category, @element.sub_group.group.title
    assert_equal "Advanced Options", @element.sub_group.title

    # Verify old group and original sub_group were cleaned up
    assert_raises(ActiveRecord::RecordNotFound) { Group.find(@group.id) }
    assert_raises(ActiveRecord::RecordNotFound) { SubGroup.find(custom_sub_group.id) }
  end

  test "handles multiple sub_groups in a group correctly" do
    # Create additional sub_groups
    advanced_sub_group = @group.sub_groups.create!(title: "Advanced Options")
    experimental_sub_group = @group.sub_groups.create!(title: "Experimental")

    # Move our existing element to the advanced sub_group
    @element.update!(
      sub_group: advanced_sub_group,
      label: "#{@ingredient.name} (Advanced)"  # Make label unique
    )

    # The original @sub_group should be cleaned up since it's now empty
    @sub_group.destroy!

    # Move to new category
    @ingredient.update!(category: "security")
    IngredientUiUpdater.call(@ingredient)

    # Verify element moved to new group and kept its sub_group title
    @element.reload
    assert_equal "security", @element.sub_group.group.title
    assert_equal "Advanced Options", @element.sub_group.title
    assert_equal "#{@ingredient.name} (Advanced)", @element.label

    # Verify only the sub_group that the element was moved from was cleaned up
    assert_raises(ActiveRecord::RecordNotFound) { SubGroup.find(advanced_sub_group.id) }

    # The experimental sub_group should still exist in the old group
    assert_nothing_raised { SubGroup.find(experimental_sub_group.id) }

    # The old group should still exist since it has the experimental sub_group
    assert_nothing_raised { Group.find(@group.id) }
  end

  test "updates attributes without moving when category hasn't changed" do
    # Create additional sub_groups to ensure we don't accidentally move or clean up
    advanced_sub_group = @group.sub_groups.create!(title: "Advanced Options")
    experimental_sub_group = @group.sub_groups.create!(title: "Experimental")

    # Store original locations
    original_group_id = @group.id
    original_sub_group_id = @sub_group.id
    original_sub_group_title = @sub_group.title

    # Update ingredient without changing category
    new_name = "Updated Name #{SecureRandom.hex(8)}"
    new_description = "New description for unchanged category"
    @ingredient.update!(
      name: new_name,
      description: new_description
    )

    IngredientUiUpdater.call(@ingredient)

    # Verify element was updated but not moved
    @element.reload
    @group.reload
    @sub_group.reload

    assert_equal new_name, @element.label
    assert_equal new_description, @element.description
    assert_equal original_group_id, @element.sub_group.group.id
    assert_equal original_sub_group_id, @element.sub_group.id
    assert_equal original_sub_group_title, @element.sub_group.title

    # Verify no groups or sub_groups were cleaned up
    assert_nothing_raised { Group.find(original_group_id) }
    assert_nothing_raised { SubGroup.find(original_sub_group_id) }
    assert_nothing_raised { SubGroup.find(advanced_sub_group.id) }
    assert_nothing_raised { SubGroup.find(experimental_sub_group.id) }

    # Verify all sub_groups still exist in the group
    @group.reload
    assert_equal 3, @group.sub_groups.count
    assert @group.sub_groups.pluck(:title).include?("Default")
    assert @group.sub_groups.pluck(:title).include?("Advanced Options")
    assert @group.sub_groups.pluck(:title).include?("Experimental")
  end

  test "preserves suffix when updating without category change" do
    # Update element to have a suffix
    @element.update!(label: "#{@ingredient.name} (Advanced)")

    # Update ingredient without changing category
    new_name = "Updated Name #{SecureRandom.hex(8)}"
    new_description = "New description for unchanged category"
    @ingredient.update!(
      name: new_name,
      description: new_description
    )

    IngredientUiUpdater.call(@ingredient)

    # Verify element was updated and kept its suffix
    @element.reload
    assert_equal "#{new_name} (Advanced)", @element.label
    assert_equal new_description, @element.description
  end

  test "updates plain label without suffix when category hasn't changed" do
    # Ensure element has no suffix
    @element.update!(label: @ingredient.name)

    # Update ingredient without changing category
    new_name = "Updated Name #{SecureRandom.hex(8)}"
    new_description = "New description for unchanged category"
    @ingredient.update!(
      name: new_name,
      description: new_description
    )

    IngredientUiUpdater.call(@ingredient)

    # Verify element was updated without any suffix
    @element.reload
    assert_equal new_name, @element.label
    assert_equal new_description, @element.description
    assert_not @element.label.include?("(")
    assert_not @element.label.include?(")")
  end

  test "updates element attributes in place when category matches" do
    # First change the category
    new_category = "security"
    @group.update!(title: new_category)
    @ingredient.update!(category: new_category)

    # Now update name and description - this should hit the else branch
    # since the category already matches
    new_name = "Updated Name #{SecureRandom.hex(8)}"
    new_description = "New description for matching category"
    @ingredient.update!(
      name: new_name,
      description: new_description
    )

    IngredientUiUpdater.call(@ingredient)

    # Verify element was updated in place
    @element.reload
    assert_equal new_name, @element.label
    assert_equal new_description, @element.description
    assert_equal new_category, @element.sub_group.group.title
  end

  test "updates element attributes when group title already matches ingredient category" do
    # Set up the scenario where group title already matches ingredient category
    matching_category = "matching-category-#{SecureRandom.hex(8)}"

    # First destroy existing groups to avoid uniqueness validation
    @element.destroy
    @variant.destroy
    @sub_group.destroy
    @group.destroy

    # Create new group with matching category
    @group = @page.groups.create!(title: matching_category, behavior_type: "custom_ingredient_checkbox")
    @sub_group = @group.sub_groups.create!(title: "Default")
    @variant = Element::CustomIngredientCheckbox.create!(
      ingredient: @ingredient,
      checked: false,
      default: false
    )
    @element = Element.create!(
      label: @ingredient.name,
      description: @ingredient.description,
      variant_type: "Element::CustomIngredientCheckbox",
      variant_id: @variant.id,
      sub_group: @sub_group,
      user: @ingredient.created_by
    )

    # Update ingredient to match the group
    @ingredient.update!(category: matching_category)

    # Now update the ingredient (without changing category)
    new_name = "Updated Name #{SecureRandom.hex(8)}"
    @ingredient.update!(name: new_name)

    # This should hit the else branch because old_group.title == ingredient.category
    IngredientUiUpdater.call(@ingredient)

    # Verify the update
    @element.reload
    assert_equal new_name, @element.label
    assert_equal matching_category, @element.sub_group.group.title
  end

  test "updates element attributes when category is exactly the same" do
    # Store the original category
    original_category = @ingredient.category
    original_group_title = @group.title

    assert_equal original_category, original_group_title, "Setup precondition: group title should match category"

    # Update ingredient with same category but new name
    new_name = "Updated Name #{SecureRandom.hex(8)}"
    @ingredient.update!(
      name: new_name,
      category: original_category  # Explicitly set the same category
    )


    IngredientUiUpdater.call(@ingredient)

    # Verify the update happened in the else branch
    @element.reload
    assert_equal new_name, @element.label
    assert_equal original_category, @element.sub_group.group.title
    assert_equal original_group_title, @element.sub_group.group.title
  end

  test "handles concurrent group deletion during cleanup" do
    # Store IDs for verification
    old_group_id = @group.id
    old_sub_group_id = @sub_group.id

    new_category = "SOMETHING_TOTALLY_DIFFERENT_#{SecureRandom.hex(8)}"

    # Disable the after_update callback temporarily
    Ingredient.skip_callback(:update, :after, :update_ui_elements)
    begin
      @ingredient.update!(category: new_category)
    ensure
      Ingredient.set_callback(:update, :after, :update_ui_elements)
    end

    # Mock reload to simulate concurrent deletion
    # First reload succeeds (when checking if sub_group is empty)
    # Second reload fails (when trying to clean up the group)
    Group.any_instance.stubs(:reload).returns(true).then.raises(ActiveRecord::RecordNotFound.new("Group was deleted concurrently"))

    # This should complete without error despite the concurrent deletion
    assert_nothing_raised do
      IngredientUiUpdater.call(@ingredient)
    end

    # Verify element was moved to the new group
    @element.reload
    assert_equal new_category, @element.sub_group.group.title
  end
end
