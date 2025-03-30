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
#  snippets         :json
#  template_content :text             not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  created_by_id    :integer          not null
#  page_id          :integer
#
# Indexes
#
#  index_ingredients_on_created_by_id           (created_by_id)
#  index_ingredients_on_name_and_created_by_id  (name,created_by_id) UNIQUE
#  index_ingredients_on_page_id                 (page_id)
#
# Foreign Keys
#
#  created_by_id  (created_by_id => users.id)
#  page_id        (page_id => pages.id)
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

  test "generates commit message" do
    @ingredient.name = "Test Ingredient"
    @ingredient.description = "A test description"
    @ingredient.id = 42

    expected_message = <<~COMMIT_MESSAGE
    * Test Ingredient (#{AppDomain.url}/ingredients/42)

      A test description

    COMMIT_MESSAGE

    assert_equal expected_message, @ingredient.to_commit_message
  end

  test "has default empty array for snippets" do
    ingredient = Ingredient.new
    assert_equal [], ingredient.snippets
  end

  test "processes multiple snippets when saving" do
    ingredient = Ingredient.new(
      name: "Test Multiple Snippets",
      template_content: "test content",
      category: "Testing",
      created_by: @user
    )

    # Set multiple snippets via the accessor
    ingredient.new_snippets = [ "puts 'Hello World'", "Rails.logger.info('Testing')" ]
    ingredient.save!

    # Check that the snippets were added to the snippets array
    assert_equal [ "puts 'Hello World'", "Rails.logger.info('Testing')" ], ingredient.snippets
  end

  test "does not add blank snippets" do
    ingredient = Ingredient.new(
      name: "Test Blank Snippets",
      template_content: "test content",
      category: "Testing",
      created_by: @user
    )

    # Set snippets with some blank values
    ingredient.new_snippets = [ "puts 'Hello'", "", "  ", nil, "puts 'World'" ]
    ingredient.save!

    # Check that only non-blank snippets were added
    assert_equal [ "puts 'Hello'", "puts 'World'" ], ingredient.snippets
  end

  test "does not modify snippets if new_snippets is empty" do
    ingredient = Ingredient.new(
      name: "Test Empty Snippets",
      template_content: "test content",
      category: "Testing",
      created_by: @user,
      snippets: [ "existing snippet" ]
    )

    # Set an empty new_snippets array
    ingredient.new_snippets = []
    ingredient.save!

    # Snippets should remain unchanged
    assert_equal [ "existing snippet" ], ingredient.snippets
  end

  test "Does not interpolate snippets into template content" do
    ingredient = Ingredient.new(
      name: "Test Ingredient",
      category: "Testing",
      template_content: 'say "This is my template"\ncreate_file "myfile.rb", {{1}}\ncreate_file "my_other_file.rb", {{2}}',
      created_by: users(:john)
    )
    ingredient.new_snippets = [ '"foo"', '"bar"' ]
    ingredient.save!

    expected_content = 'say "This is my template"\ncreate_file "myfile.rb", {{1}}\ncreate_file "my_other_file.rb", {{2}}'
    assert_equal expected_content, ingredient.template_content
  end

  test "handles template without placeholders" do
    ingredient = Ingredient.new(
      name: "Test Ingredient",
      category: "Testing",
      template_content: 'say "This is my template"',
      created_by: users(:john)
    )
    ingredient.new_snippets = [ '"foo"', '"bar"' ]
    ingredient.save!

    assert_equal 'say "This is my template"', ingredient.template_content
  end

  test "template_with_interpolated_snippets with no snippets returns original template" do
    ingredient = Ingredient.new(template_content: "some template", snippets: [])
    assert_equal "some template", ingredient.template_with_interpolated_snippets
  end

  test "template_with_interpolated_snippets interpolates single-line snippets" do
    ingredient = Ingredient.new(
      template_content: "First {{1}} and then {{2}}",
      snippets: [ "hello", "world" ]
    )
    assert_equal "First \"hello\" and then \"world\"", ingredient.template_with_interpolated_snippets
  end

  test "template_with_interpolated_snippets interpolates multi-line snippets" do
    ingredient = Ingredient.new(
      template_content: "Code:\n{{1}}\nMore code:\n{{2}}",
      snippets: [ "def foo\n  puts 'bar'\nend", "x = 1" ]
    )
    expected = <<~EXPECTED
      Code:
      <<~SNIPPET_1
      def foo
        puts 'bar'
      end
      SNIPPET_1

      More code:
      "x = 1"
    EXPECTED
    assert_equal expected.chomp, ingredient.template_with_interpolated_snippets
  end

  test "template_with_interpolated_snippets preserves heredoc snippets" do
    ingredient = Ingredient.new(
      template_content: "Code: {{1}}",
      snippets: [ "<<~SQL\nSELECT * FROM users\nSQL" ]
    )
    assert_equal "Code: <<~SQL\nSELECT * FROM users\nSQL", ingredient.template_with_interpolated_snippets
  end

  test "template_with_interpolated_snippets preserves quoted snippets" do
    ingredient = Ingredient.new(
      template_content: "Text: {{1}}",
      snippets: [ "'already quoted'" ]
    )
    assert_equal "Text: 'already quoted'", ingredient.template_with_interpolated_snippets
  end
end
