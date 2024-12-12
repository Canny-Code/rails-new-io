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
    stub_git_operations(@recipe)
  end

  test "adds ingredient with configuration" do
    configuration = { "auth_type" => "devise" }
    initial_position = @recipe.recipe_ingredients.maximum(:position).to_i

    @recipe.add_ingredient!(@ingredient, configuration)

    recipe_ingredient = @recipe.recipe_ingredients.last
    assert_equal @ingredient, recipe_ingredient.ingredient
    assert_equal initial_position + 1, recipe_ingredient.position
    assert_equal configuration, recipe_ingredient.configuration
  end

  test "creates a commit when adding ingredient" do
    @recipe.expects(:commit!).with("Added ingredient: #{@ingredient.name}").once
    @recipe.add_ingredient!(@ingredient, { "auth_type" => "devise" })
  end

  test "raises error when adding incompatible ingredient" do
    # Create a conflicting ingredient that conflicts with Rails Authentication
    conflicting = Ingredient.new(
      name: "Conflicting Auth",
      description: "Another auth system",
      template_content: "# Template",
      conflicts_with: [],  # This ingredient doesn't conflict with anything
      requires: [],
      configures_with: { "auth_type" => [ "other" ] },
      created_by: @user
    )
    stub_git_operations(conflicting)
    conflicting.save!

    # Modify the existing ingredient to conflict with the new one
    @ingredient.update!(conflicts_with: [ "Conflicting Auth" ])

    # Add first ingredient
    @recipe.add_ingredient!(@ingredient, { "auth_type" => "devise" })

    # Try to add conflicting ingredient
    assert_raises(Recipe::IncompatibleIngredientError) do
      @recipe.add_ingredient!(conflicting, { "auth_type" => "other" })
    end
  end

  test "raises error when ingredient dependencies not met" do
    # Create an ingredient with unmet dependencies
    dependent = Ingredient.new(
      name: "Dependent Auth",
      description: "Auth requiring something",
      template_content: "# Template",
      conflicts_with: [],
      requires: [ "some_other_ingredient" ],
      configures_with: { "auth_type" => [ "other" ] },
      created_by: @user
    )
    stub_git_operations(dependent)  # Stub git operations before save
    dependent.save!

    assert_raises(Recipe::IncompatibleIngredientError) do
      @recipe.add_ingredient!(dependent, { "auth_type" => "other" })
    end
  end
end
