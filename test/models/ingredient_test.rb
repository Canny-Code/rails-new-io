# == Schema Information
#
# Table name: ingredients
#
#  id               :integer          not null, primary key
#  category         :string
#  configures_with  :text
#  conflicts_with   :text
#  description      :text
#  name             :string           not null
#  requires         :text
#  template_content :text             not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  created_by_id    :integer          not null
#
# Indexes
#
#  index_ingredients_on_created_by_id  (created_by_id)
#  index_ingredients_on_name           (name) UNIQUE
#
# Foreign Keys
#
#  created_by_id  (created_by_id => users.id)
#
require "test_helper"

class IngredientTest < ActiveSupport::TestCase
  setup do
    @ingredient = ingredients(:rails_authentication)
    @user = users(:john)
  end

  test "validates presence of name" do
    @ingredient.name = nil
    assert_not @ingredient.valid?
    assert_includes @ingredient.errors[:name], "can't be blank"
  end

  test "validates uniqueness of name" do
    duplicate = @ingredient.dup
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:name], "has already been taken"
  end

  test "validates presence of template_content" do
    @ingredient.template_content = nil
    assert_not @ingredient.valid?
    assert_includes @ingredient.errors[:template_content], "can't be blank"
  end

  test "belongs to created_by" do
    assert_respond_to @ingredient, :created_by
    assert_instance_of User, @ingredient.created_by
  end

  test "has many recipe_ingredients" do
    assert_respond_to @ingredient, :recipe_ingredients
    assert_kind_of ActiveRecord::Associations::CollectionProxy, @ingredient.recipe_ingredients
  end

  test "has many recipes" do
    assert_respond_to @ingredient, :recipes
    assert_kind_of ActiveRecord::Associations::CollectionProxy, @ingredient.recipes
  end

  test "has many app_changes" do
    assert_respond_to @ingredient, :app_changes
    assert_kind_of ActiveRecord::Associations::CollectionProxy, @ingredient.app_changes
  end

  test "serializes conflicts_with" do
    @ingredient.conflicts_with = [ "devise-jwt" ]
    @ingredient.save!
    @ingredient.reload

    assert_equal [ "devise-jwt" ], @ingredient.conflicts_with
  end

  test "serializes requires" do
    @ingredient.requires = [ "devise" ]
    @ingredient.save!
    @ingredient.reload

    assert_equal [ "devise" ], @ingredient.requires
  end

  test "serializes configures_with" do
    config = { "user_model" => [ "User", "Admin" ] }
    @ingredient.configures_with = config
    @ingredient.save!
    @ingredient.reload

    assert_equal config, @ingredient.configures_with
  end

  test "checks compatibility with other ingredient" do
    auth = ingredients(:rails_authentication)
    api = ingredients(:api_setup)

    auth.conflicts_with = [ api.name ]

    assert_not auth.compatible_with?(api)
    assert api.compatible_with?(auth)
  end

  test "checks dependency satisfaction" do
    recipe = recipes(:blog_recipe)
    api = ingredients(:api_setup)
    auth = ingredients(:rails_authentication)

    # First test with a dependency that exists in the recipe
    auth.requires = [ api.name ]

    # Find the next available position
    next_position = (recipe.recipe_ingredients.maximum(:position) || 0) + 1

    recipe.recipe_ingredients.create!(
      ingredient: api,
      position: next_position,
      configuration: { "key" => "value" }  # Add some valid configuration
    )

    assert auth.dependencies_satisfied?(recipe)

    # Then test with a missing dependency
    auth.requires = [ "non-existent-ingredient" ]
    assert_not auth.dependencies_satisfied?(recipe)
  end

  test "validates configuration against array validator" do
    @ingredient.configures_with = { "auth_type" => [ "devise", "rodauth" ] }

    assert_nothing_raised do
      @ingredient.configuration_for({ "auth_type" => "devise" })
    end

    error = assert_raises(Ingredient::InvalidConfigurationError) do
      @ingredient.configuration_for({ "auth_type" => "invalid" })
    end
    assert_match /Invalid value for auth_type/, error.message
  end

  test "validates configuration against hash validator" do
    @ingredient.configures_with = {
      "user_model" => { required: true, values: [ "User", "Admin" ] }
    }

    assert_nothing_raised do
      @ingredient.configuration_for({ "user_model" => "User" })
    end

    assert_raises(Ingredient::InvalidConfigurationError) do
      @ingredient.configuration_for({ "user_model" => "Invalid" })
    end

    assert_raises(Ingredient::InvalidConfigurationError) do
      @ingredient.configuration_for({})
    end
  end

  test "validates configuration against custom validator" do
    # Use a hash with a custom validation rule instead of a Proc
    @ingredient.configures_with = {
      "max_users" => {
        required: true,
        validate: "positive_integer"
      }
    }

    assert_nothing_raised do
      @ingredient.configuration_for({ "max_users" => "10" })
    end

    error = assert_raises(Ingredient::InvalidConfigurationError) do
      @ingredient.configuration_for({ "max_users" => "0" })
    end
    assert_match /Invalid value for max_users/, error.message

    error = assert_raises(Ingredient::InvalidConfigurationError) do
      @ingredient.configuration_for({})
    end
    assert_match /required/, error.message
  end

  test "processes ERB template with configuration" do
    # Set up a simple template and configuration schema
    @ingredient.template_content = "gem '<%= gem_name %>'"
    @ingredient.configures_with = { "gem_name" => { required: true } }

    result = @ingredient.configuration_for({ "gem_name" => "devise" })
    assert_equal "gem 'devise'", result
  end

  test "allows nil values for optional configuration" do
    @ingredient.configures_with = {
      "optional" => { required: false }
    }

    assert_nothing_raised do
      @ingredient.configuration_for({})
    end
  end
end
