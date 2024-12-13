# == Schema Information
#
# Table name: recipe_changes
#
#  id            :integer          not null, primary key
#  applied_at    :datetime
#  change_data   :json             not null
#  change_type   :string           not null
#  description   :text
#  error_message :text
#  success       :boolean
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  ingredient_id :integer
#  recipe_id     :integer          not null
#
# Indexes
#
#  index_recipe_changes_on_ingredient_id  (ingredient_id)
#  index_recipe_changes_on_recipe_id      (recipe_id)
#
# Foreign Keys
#
#  ingredient_id  (ingredient_id => ingredients.id)
#  recipe_id      (recipe_id => recipes.id) ON DELETE => cascade
#
require "test_helper"

class RecipeChangeTest < ActiveSupport::TestCase
  setup do
    @recipe = recipes(:blog_recipe)
    @ingredient = ingredients(:rails_authentication)
    @add_change = recipe_changes(:add_ingredient_change)
    @remove_change = recipe_changes(:remove_ingredient_change)
    @reorder_change = recipe_changes(:reorder_change)
    @config_change = recipe_changes(:config_change)
    @applied_change = recipe_changes(:applied_change)
  end

  test "validates presence of required fields" do
    change = RecipeChange.new
    assert_not change.valid?
    assert_includes change.errors[:change_type], "can't be blank"
    assert_includes change.errors[:change_data], "can't be blank"
  end

  test "validates change_type inclusion" do
    change = RecipeChange.new(change_type: "invalid")
    assert_not change.valid?
    assert_includes change.errors[:change_type], "is not included in the list"
  end

  test "belongs to recipe" do
    assert_respond_to @add_change, :recipe
    assert_instance_of Recipe, @add_change.recipe
  end

  test "belongs to ingredient optionally" do
    assert_respond_to @add_change, :ingredient
    assert_instance_of Ingredient, @add_change.ingredient
    assert @reorder_change.valid?, "should be valid without ingredient"
  end

  test "has many app changes" do
    assert_respond_to @add_change, :app_changes
    assert_kind_of ActiveRecord::Associations::CollectionProxy, @add_change.app_changes
  end

  test "applies add ingredient change" do
    mock_recipe = mock("recipe")
    mock_recipe.expects(:add_ingredient!).with(
      @ingredient,
      @add_change.change_data["configuration"]
    ).once

    @add_change.stubs(:recipe).returns(mock_recipe)

    @add_change.apply!

    assert @add_change.applied_at.present?
    assert @add_change.success
  end

  test "applies remove ingredient change" do
    mock_recipe = mock("recipe")
    mock_recipe.expects(:remove_ingredient!).with(@ingredient).once

    @remove_change.stubs(:recipe).returns(mock_recipe)

    @remove_change.apply!

    assert @remove_change.applied_at.present?
    assert @remove_change.success
  end

  test "applies reorder ingredients change" do
    mock_recipe = mock("recipe")
    mock_recipe.expects(:reorder_ingredients!).with(@reorder_change.change_data["order"]).once

    @reorder_change.stubs(:recipe).returns(mock_recipe)

    @reorder_change.apply!

    assert @reorder_change.applied_at.present?
    assert @reorder_change.success
  end

  test "applies configuration change" do
    mock_recipe = mock("recipe")
    mock_recipe.expects(:update!).with(@config_change.change_data["configuration"]).once

    @config_change.stubs(:recipe).returns(mock_recipe)

    @config_change.apply!

    assert @config_change.applied_at.present?
    assert @config_change.success
  end

  test "handles errors during application" do
    mock_recipe = mock("recipe")
    mock_recipe.expects(:add_ingredient!).raises(ActiveRecord::RecordInvalid.new(@recipe))

    @add_change.stubs(:recipe).returns(mock_recipe)

    assert_raises ActiveRecord::RecordInvalid do
      @add_change.apply!
    end

    assert @add_change.applied_at.present?
    assert_not @add_change.success
    assert @add_change.error_message.present?
  end

  test "skips already applied changes" do
    assert_no_changes -> { @applied_change.attributes } do
      @applied_change.apply!
    end
  end

  test "apply_to_app generates template for add ingredient" do
    config = { user_model: "Admin" }
    expected_template = "template content"

    # Create a mock ingredient
    mock_ingredient = mock("ingredient")
    mock_ingredient.expects(:configuration_for).with(config).returns(expected_template)

    # Make the change use our mock ingredient
    @add_change.stubs(:ingredient).returns(mock_ingredient)

    result = @add_change.apply_to_app(nil, config)
    assert_equal expected_template, result
  end

  test "apply_to_app generates template for remove ingredient" do
    # Create a mock ingredient with name
    mock_ingredient = mock("ingredient")
    mock_ingredient.stubs(:name).returns("test_ingredient")

    @remove_change.stubs(:ingredient).returns(mock_ingredient)

    result = @remove_change.apply_to_app(nil)

    assert_includes result, "gsub_file"
    assert_includes result, "test_ingredient"
  end

  test "apply_to_app generates template for reorder" do
    # Create mock ingredients for reorder
    mock_ingredients = [ mock("ingredient1"), mock("ingredient2") ]
    mock_ingredients.each do |mi|
      mi.stubs(:template_content).returns("template #{mi.__id__}")
    end

    # Create mock relation chain
    mock_relation = mock("relation")
    mock_relation.stubs(:includes).returns(mock_relation)
    mock_relation.stubs(:order).returns(mock_ingredients)

    mock_recipe = mock("recipe")
    mock_recipe.stubs(:ingredients).returns(mock_relation)

    @reorder_change.stubs(:recipe).returns(mock_recipe)

    result = @reorder_change.apply_to_app(nil)

    assert_kind_of String, result
    assert result.present?
    mock_ingredients.each do |mi|
      assert_includes result, "template #{mi.__id__}"
    end
  end

  test "apply_to_app generates template for configuration" do
    result = @config_change.apply_to_app(nil)

    assert_includes result, "inject_into_file"
    assert_includes result, "config/application.rb"
  end

  test "apply_to_app raises error for unknown change type" do
    @add_change.change_type = "unknown"

    assert_raises ArgumentError do
      @add_change.apply_to_app(nil)
    end
  end
end
