require "test_helper"
require_relative "../support/git_test_helper"

class DataRepositoryServiceTest < ActiveSupport::TestCase
  include GitTestHelper

  def setup
    super  # Add this line to ensure fixtures are properly loaded
    @user = users(:john)
    @repo_name = DataRepositoryService.name_for_environment
    @service = DataRepositoryService.new(user: @user)
    setup_github_mocks
  end

  test "initializes repository with correct structure" do
    expect_github_operations(create_repo: true, expect_git_operations: true)

    result = @service.initialize_repository
    assert_equal "https://github.com/#{@user.github_username}/#{@repo_name}", result.html_url
  end

  test "writes ingredient to repository" do
    ingredient = Data.define(:name, :template_content).new(
      name: "test_ingredient",
      template_content: "# Test template"
    )

    expect_github_operations(expect_git_operations: true, create_repo: false)

    @service.write_ingredient(ingredient, repo_name: @repo_name)
  end

  test "writes recipe to repository" do
    recipe = Data.define(:name, :to_yaml).new(
      name: "test_recipe",
      to_yaml: "# Test recipe YAML"
    )

    expect_github_operations(expect_git_operations: true, create_repo: false)

    @service.write_recipe(recipe, repo_name: @repo_name)
  end
end
