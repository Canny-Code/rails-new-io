# == Schema Information
#
# Table name: recipe_ingredients
#
#  id            :integer          not null, primary key
#  applied_at    :datetime
#  configuration :json
#  position      :integer          not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  ingredient_id :integer          not null
#  recipe_id     :integer          not null
#
# Indexes
#
#  index_recipe_ingredients_on_ingredient_id           (ingredient_id)
#  index_recipe_ingredients_on_recipe_id               (recipe_id)
#  index_recipe_ingredients_on_recipe_id_and_position  (recipe_id,position) UNIQUE
#
# Foreign Keys
#
#  ingredient_id  (ingredient_id => ingredients.id)
#  recipe_id      (recipe_id => recipes.id)
#
require "test_helper"
require_relative "../support/git_test_helper"

class RecipeIngredientTest < ActiveSupport::TestCase
  include GitTestHelper

  setup do
    @recipe = recipes(:blog_recipe)
    @ingredient = ingredients(:rails_authentication)
    @recipe_ingredient = recipe_ingredients(:blog_auth)
  end

  test "validates presence of position" do
    recipe_ingredient = @recipe.recipe_ingredients.build(
      ingredient: @ingredient,
      configuration: { "auth_type" => "devise" }
    )
    assert_not recipe_ingredient.valid?
    assert_includes recipe_ingredient.errors[:position], "can't be blank"
  end

  test "validates uniqueness of position within recipe" do
    existing_position = @recipe_ingredient.position
    duplicate = @recipe.recipe_ingredients.build(
      ingredient: ingredients(:api_setup),
      position: existing_position,
      configuration: { "versioning" => true }
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:position], "has already been taken"
  end

  test "converts to git format" do
    stub_git_operations(@recipe, expect_sync: false)
    @recipe_ingredient.applied_at = Time.current
    expected = {
      ingredient_name: @ingredient.name,
      position: @recipe_ingredient.position,
      configuration: @recipe_ingredient.configuration,
      applied_at: @recipe_ingredient.applied_at.iso8601
    }

    assert_equal expected, @recipe_ingredient.to_git_format
  end

  test "applies ingredient configuration" do
    stub_git_operations(@recipe, expect_sync: false)
    freeze_time do
      # Ensure applied_at is nil
      assert_nil @recipe_ingredient.applied_at, "applied_at should be nil before test"

      # Set and verify configuration
      @recipe_ingredient.configuration = { "auth_type" => "devise" }
      assert_equal({ "auth_type" => "devise" }, @recipe_ingredient.configuration)

      # Mock the configuration processing
      @recipe_ingredient.ingredient.expects(:configuration_for).
        with(@recipe_ingredient.configuration).
        returns("# Template content")

      # Call apply! and verify it's not returning early
      result = @recipe_ingredient.apply!

      # Verify the update happened
      @recipe_ingredient.reload
      assert_equal Time.current, @recipe_ingredient.applied_at
    end
  end

  test "does not reapply if already applied" do
    stub_git_operations(@recipe, expect_sync: false)
    @recipe_ingredient.update!(applied_at: 1.day.ago)
    @ingredient.expects(:configuration_for).never

    @recipe_ingredient.apply!
  end
end
