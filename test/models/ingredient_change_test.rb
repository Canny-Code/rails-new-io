require "test_helper"

class IngredientChangeTest < ActiveSupport::TestCase
  setup do
    @ingredient = ingredients(:rails_authentication)
    @template_change = ingredient_changes(:template_change)
    @schema_change = ingredient_changes(:schema_change)
    @dependencies_change = ingredient_changes(:dependencies_change)
    @applied_change = ingredient_changes(:applied_change)
  end

  test "validates presence of required fields" do
    change = IngredientChange.new
    assert_not change.valid?
    assert_includes change.errors[:change_type], "can't be blank"
    assert_includes change.errors[:change_data], "can't be blank"
  end

  test "validates change_type inclusion" do
    change = IngredientChange.new(change_type: "invalid")
    assert_not change.valid?
    assert_includes change.errors[:change_type], "is not included in the list"
  end

  test "applies template changes" do
    original_content = @ingredient.template_content

    @template_change.apply!

    assert_not_equal original_content, @ingredient.reload.template_content
    assert_equal "new template content", @ingredient.template_content
    assert @template_change.applied_at.present?
    assert @template_change.success
  end

  test "applies schema changes" do
    original_schema = @ingredient.configures_with

    @schema_change.apply!

    assert_not_equal original_schema, @ingredient.reload.configures_with
    assert_equal({ "new" => "schema" }, @ingredient.configures_with)
    assert @schema_change.applied_at.present?
    assert @schema_change.success
  end

  test "applies dependencies changes" do
    original_conflicts = @ingredient.conflicts_with.dup
    original_requires = @ingredient.requires.dup

    @dependencies_change.apply!

    @ingredient.reload
    assert_not_equal original_conflicts, @ingredient.conflicts_with
    assert_not_equal original_requires, @ingredient.requires
    assert_equal [ "conflict1" ], @ingredient.conflicts_with
    assert_equal [ "require1" ], @ingredient.requires
    assert @dependencies_change.applied_at.present?
    assert @dependencies_change.success
  end

  test "handles errors during application" do
    invalid_ingredient = ingredients(:rails_authentication)
    invalid_ingredient.expects(:update!).raises(ActiveRecord::RecordInvalid.new(invalid_ingredient))

    @template_change.stubs(:ingredient).returns(invalid_ingredient)

    assert_raises ActiveRecord::RecordInvalid do
      @template_change.apply!
    end

    assert @template_change.applied_at.present?
    assert_not @template_change.success
    assert @template_change.error_message.present?
  end

  test "skips already applied changes" do
    assert_no_changes -> { @applied_change.attributes } do
      @applied_change.apply!
    end
  end

  test "belongs to ingredient" do
    assert_respond_to @template_change, :ingredient
    assert_instance_of Ingredient, @template_change.ingredient
  end
end
