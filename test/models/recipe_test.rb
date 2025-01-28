# == Schema Information
#
# Table name: recipes
#
#  id              :integer          not null, primary key
#  cli_flags       :string
#  description     :text
#  head_commit_sha :string
#  name            :string           not null
#  rails_version   :string
#  ruby_version    :string
#  status          :string           default("draft")
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  created_by_id   :integer          not null
#
# Indexes
#
#  index_recipes_on_created_by_id  (created_by_id)
#
# Foreign Keys
#
#  created_by_id  (created_by_id => users.id)
#
require "test_helper"
require_relative "../support/git_test_helper"

class RecipeTest < ActiveSupport::TestCase
  include GitTestHelper

  setup do
    @recipe = recipes(:blog_recipe)
    @ingredient = ingredients(:rails_authentication)
    @user = users(:john)
    setup_github_mocks(@recipe)
  end

  test "adds ingredient with configuration" do
    configuration = { "auth_type" => "devise" }
    initial_position = @recipe.recipe_ingredients.maximum(:position).to_i

    @recipe.unstub(:sync_to_git)  # Remove the stub so we can set an expectation
    @recipe.expects(:sync_to_git).once

    @recipe.add_ingredient!(@ingredient, configuration)

    recipe_ingredient = @recipe.recipe_ingredients.last
    assert_equal @ingredient, recipe_ingredient.ingredient
    assert_equal initial_position + 1, recipe_ingredient.position
    assert_equal configuration, recipe_ingredient.configuration
  end

  test "creates a commit when adding ingredient" do
    @recipe.unstub(:sync_to_git)  # Remove the stub so we can set an expectation
    @recipe.expects(:sync_to_git).once
    @recipe.add_ingredient!(@ingredient, { "auth_type" => "devise" })
  end

  # test "raises error when adding incompatible ingredient" do
  #   # Create a conflicting ingredient that conflicts with Rails Authentication
  #   conflicting = Ingredient.new(
  #     name: "Conflicting Auth",
  #     description: "Another auth system",
  #     template_content: "# Template",
  #     conflicts_with: [],  # This ingredient doesn't conflict with anything
  #     requires: [],
  #     configures_with: { "auth_type" => [ "other" ] },
  #     created_by: @user
  #   )
  #   stub_git_operations(conflicting)
  #   conflicting.save!

  #   # Modify the existing ingredient to conflict with the new one
  #   @ingredient.update!(conflicts_with: [ "Conflicting Auth" ])

  #   # Add first ingredient
  #   @recipe.add_ingredient!(@ingredient, { "auth_type" => "devise" })

  #   # Try to add conflicting ingredient
  #   assert_raises(Recipe::IncompatibleIngredientError) do
  #     @recipe.add_ingredient!(conflicting, { "auth_type" => "other" })
  #   end
  # end

  # test "raises error when ingredient dependencies not met" do
  #   # Create an ingredient with unmet dependencies
  #   dependent = Ingredient.new(
  #     name: "Dependent Auth",
  #     description: "Auth requiring something",
  #     template_content: "# Template",
  #     conflicts_with: [],
  #     requires: [ "some_other_ingredient" ],
  #     configures_with: { "auth_type" => [ "other" ] },
  #     created_by: @user
  #   )
  #   stub_git_operations(dependent)  # Stub git operations before save
  #   dependent.save!

  #   assert_raises(Recipe::IncompatibleIngredientError) do
  #     @recipe.add_ingredient!(dependent, { "auth_type" => "other" })
  #   end
  # end

  test "removes ingredient and reorders positions" do
    initial_count = @recipe.recipe_ingredients.count
    @recipe.add_ingredient!(@ingredient, { "auth_type" => "devise" })
    @recipe.unstub(:sync_to_git)  # Remove the stub so we can set an expectation
    @recipe.expects(:sync_to_git).at_least_once

    assert_difference("@recipe.recipe_ingredients.count", -1) do
      @recipe.remove_ingredient!(@ingredient)
    end

    assert_equal initial_count, @recipe.recipe_ingredients.count
  end

  test "reorders ingredients and creates a commit" do
    # First clear existing recipe ingredients to start fresh
    @recipe.recipe_ingredients.destroy_all

    # Add ingredients in initial order
    ingredient2 = ingredients(:api_setup)
    @recipe.add_ingredient!(@ingredient, { "auth_type" => "devise" })
    @recipe.add_ingredient!(ingredient2, { "versioning" => true })

    # Remove the stub so we can set an expectation
    @recipe.unstub(:sync_to_git)
    @recipe.expects(:sync_to_git).at_least_once

    # Reorder ingredients
    new_order = [ ingredient2.id, @ingredient.id ]
    @recipe.reorder_ingredients!(new_order)

    # Verify new order
    assert_equal new_order, @recipe.recipe_ingredients.order(:position).pluck(:ingredient_id)
  end

  # test "ingredient compatibility check" do
  #   # Test 1: Basic compatibility
  #   compatible_ingredient = Ingredient.new(
  #     name: "Compatible",
  #     description: "A compatible ingredient",
  #     template_content: "# Template",
  #     conflicts_with: [],  # No conflicts
  #     requires: [],        # No dependencies
  #     configures_with: {},
  #     created_by: @user
  #   )
  #   stub_git_operations(compatible_ingredient)
  #   compatible_ingredient.save!

  #   assert @recipe.send(:ingredient_compatible?, compatible_ingredient)

  #   # Test 2: Dependency check
  #   dependent = Ingredient.new(
  #     name: "Dependent Auth",
  #     description: "Auth requiring something",
  #     template_content: "# Template",
  #     conflicts_with: [],
  #     requires: [ "some_other_ingredient" ],
  #     configures_with: { "auth_type" => [ "other" ] },
  #     created_by: @user
  #   )
  #   stub_git_operations(dependent)  # Stub git operations before save
  #   dependent.save!

  #   assert_not @recipe.send(:ingredient_compatible?, dependent)
  # end

  test "next position calculation" do
    # First clear existing recipe ingredients to start fresh
    @recipe.recipe_ingredients.destroy_all

    assert_equal 1, @recipe.send(:next_position)
    @recipe.add_ingredient!(@ingredient, { "auth_type" => "devise" })
    assert_equal 2, @recipe.send(:next_position)
  end

  test "reorder positions" do
    # First clear existing recipe ingredients to start fresh
    @recipe.recipe_ingredients.destroy_all

    @recipe.add_ingredient!(@ingredient, { "auth_type" => "devise" })
    ingredient2 = ingredients(:api_setup)
    @recipe.add_ingredient!(ingredient2, { "versioning" => true })

    # Set positions to temporary values first (using large numbers to avoid conflicts)
    @recipe.recipe_ingredients.first.update!(position: 1000)
    @recipe.recipe_ingredients.last.update!(position: 2000)

    @recipe.send(:reorder_positions)

    assert_equal [ 1, 2 ], @recipe.recipe_ingredients.order(:position).pluck(:position)
  end

  test "find_duplicate returns nil when no recipes with matching cli_flags exist" do
    recipe = recipes(:blog_recipe)
    recipe.update!(cli_flags: "--api")
    assert_nil Recipe.find_duplicate("--some-flag-that-does-not-exist")
  end

  test "find_duplicate returns nil when recipes have same cli_flags but different ingredients" do
    ingredient1 = ingredients(:rails_authentication)
    ingredient2 = ingredients(:api_setup)

    recipe1 = recipes(:blog_recipe)
    recipe1.update!(cli_flags: "--api --skip-turbo")
    recipe1.recipe_ingredients.destroy_all  # Clear existing ingredients first
    recipe1.add_ingredient!(ingredient1)

    recipe2 = recipes(:minimal_recipe)
    recipe2.update!(cli_flags: "--api --skip-turbo")
    recipe2.recipe_ingredients.destroy_all  # Clear existing ingredients first
    recipe2.add_ingredient!(ingredient2)

    assert_nil Recipe.find_duplicate("--api --skip-turbo")
  end

  test "find_duplicate returns nil when recipes have same cli_flags and some common ingredients" do
    ingredient1 = ingredients(:rails_authentication)
    ingredient2 = ingredients(:api_setup)
    ingredient3 = ingredients(:basic)

    recipe1 = recipes(:blog_recipe)
    recipe1.update!(cli_flags: "--api --skip-turbo")
    recipe1.recipe_ingredients.destroy_all
    recipe1.add_ingredient!(ingredient1)
    recipe1.add_ingredient!(ingredient2)

    recipe2 = recipes(:minimal_recipe)
    recipe2.update!(cli_flags: "--api --skip-turbo")
    recipe2.recipe_ingredients.destroy_all
    recipe2.add_ingredient!(ingredient1)
    recipe2.add_ingredient!(ingredient3)

    assert_nil Recipe.find_duplicate("--api --skip-turbo")
  end

  test "find_duplicate returns recipe when exact match exists" do
    ingredient1 = ingredients(:rails_authentication)
    ingredient2 = ingredients(:api_setup)

    recipe1 = recipes(:blog_recipe)
    recipe1.update!(cli_flags: "--api")
    recipe1.recipe_ingredients.destroy_all  # Clear existing ingredients
    recipe1.add_ingredient!(ingredient1)
    recipe1.add_ingredient!(ingredient2)

    recipe2 = recipes(:minimal_recipe)
    recipe2.update!(cli_flags: "--api")
    recipe2.recipe_ingredients.destroy_all  # Clear existing ingredients
    recipe2.add_ingredient!(ingredient1)
    recipe2.add_ingredient!(ingredient2)

    assert_equal recipe1, Recipe.find_duplicate("--api")
  end

  test "find_duplicate matches ingredients regardless of their order" do
    ingredient1 = ingredients(:rails_authentication)
    ingredient2 = ingredients(:api_setup)

    recipe1 = recipes(:blog_recipe)
    recipe1.update!(cli_flags: "--api")
    recipe1.recipe_ingredients.destroy_all  # Clear existing ingredients
    recipe1.add_ingredient!(ingredient1)
    recipe1.add_ingredient!(ingredient2)

    recipe2 = recipes(:minimal_recipe)
    recipe2.update!(cli_flags: "--api")
    recipe2.recipe_ingredients.destroy_all  # Clear existing ingredients
    recipe2.add_ingredient!(ingredient2)
    recipe2.add_ingredient!(ingredient1)

    assert_equal recipe1, Recipe.find_duplicate("--api", [ ingredient1.id, ingredient2.id ])
  end

  test "find_duplicate returns nil when recipes have same ingredients but different cli_flags" do
    ingredient1 = ingredients(:rails_authentication)
    ingredient2 = ingredients(:api_setup)

    recipe1 = recipes(:blog_recipe)
    recipe1.update!(cli_flags: "--api --skip-turbo")
    recipe1.add_ingredient!(ingredient1)
    recipe1.add_ingredient!(ingredient2)

    recipe2 = recipes(:minimal_recipe)
    recipe2.update!(cli_flags: "--minimal")
    recipe2.add_ingredient!(ingredient1)
    recipe2.add_ingredient!(ingredient2)

    assert_nil Recipe.find_duplicate("--api --skip-turbo")
  end

  test "find_duplicate works with recipes that have no ingredients" do
    recipe1 = recipes(:blog_recipe)
    recipe1.update!(cli_flags: "--api")
    recipe1.recipe_ingredients.destroy_all

    recipe2 = recipes(:minimal_recipe)
    recipe2.update!(cli_flags: "--api")
    recipe2.recipe_ingredients.destroy_all

    assert_equal recipe1, Recipe.find_duplicate("--api")
  end

  test "find_duplicate returns existing recipe when both have no ingredients but same flags" do
    # Create first recipe with no ingredients
    recipe1 = recipes(:blog_recipe)
    recipe1.update!(cli_flags: "--api")
    recipe1.recipe_ingredients.destroy_all

    # Create second recipe with no ingredients
    recipe2 = recipes(:minimal_recipe)
    recipe2.update!(cli_flags: "--api")
    recipe2.recipe_ingredients.destroy_all

    assert_equal recipe1, Recipe.find_duplicate("--api")
  end
end
