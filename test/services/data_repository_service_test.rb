require "test_helper"
require_relative "../support/git_test_helper"

class DataRepositoryServiceTest < ActiveSupport::TestCase
  include GitTestHelper

  def setup
    super  # Add this line to ensure fixtures are properly loaded
    @user = users(:john)
    @repo_name = DataRepositoryService.name_for_environment
    @service = DataRepositoryService.new(user: @user)

    mocks = setup_github_mocks
    @mock_client = mocks.client
    @first_ref_mock = mocks.first_ref
    @second_ref_mock = mocks.second_ref
    @commit_mock = mocks.commit
    @tree_mock = mocks.tree
    @new_commit_mock = mocks.new_commit
  end

  test "initializes repository with correct structure" do
    repo_full_name = "#{@user.github_username}/#{@repo_name}"

    @mock_client.expects(:repository?).with(repo_full_name).returns(false)
    @mock_client.expects(:create_repository).with(
      @repo_name,
      private: false,
      auto_init: true,
      description: "Repository created via railsnew.io",
      default_branch: "main"
    ).returns(@new_commit_mock)

    # First ref call to get base tree SHA
    @mock_client.expects(:ref).with(repo_full_name, "heads/main").returns(@first_ref_mock)
    @mock_client.expects(:commit).with(repo_full_name, "old_sha").returns(@commit_mock)
    @mock_client.expects(:create_tree).with(
      repo_full_name,
      [
        {
          path: "README.md",
          mode: "100644",
          type: "blob",
          content: "# Data Repository\nThis repository contains data for railsnew.io"
        },
        {
          path: "ingredients/.keep",
          mode: "100644",
          type: "blob",
          content: ""
        },
        {
          path: "recipes/.keep",
          mode: "100644",
          type: "blob",
          content: ""
        }
      ],
      base_tree: "tree_sha"
    ).returns(@tree_mock)

    # Second ref call to get latest commit SHA for parent
    @mock_client.expects(:ref).with(repo_full_name, "heads/main").returns(@first_ref_mock)

    # Create commit with the latest commit SHA as parent
    @mock_client.expects(:create_commit).with(
      repo_full_name,
      "Initialize repository structure",
      "new_tree_sha",
      "old_sha",
      author: {
        name: @user.name,
        email: @user.email
      }
    ).returns(@new_commit_mock)

    # Update ref to point to new commit
    @mock_client.expects(:update_ref).with(
      repo_full_name,
      "heads/main",
      "new_sha"
    )

    # Just assert that it doesn't raise an error
    assert_nothing_raised do
      @service.initialize_repository
    end
  end

  test "writes ingredient to repository" do
    ingredient = Data.define(:name, :template_content).new(
      name: "test_ingredient",
      template_content: "# Test template"
    )

    repo_full_name = "#{@user.github_username}/#{@repo_name}"

    # Mock the GitHub API calls in sequence
    # First ref call to get base tree SHA
    @mock_client.expects(:ref).with(repo_full_name, "heads/main").returns(@first_ref_mock)
    @mock_client.expects(:commit).with(repo_full_name, "old_sha").returns(@commit_mock)
    @mock_client.expects(:create_tree).with(
      repo_full_name,
      [
        {
          path: "ingredients/test_ingredient/template.rb",
          mode: "100644",
          type: "blob",
          content: "# Test template"
        }
      ],
      base_tree: "tree_sha"
    ).returns(@tree_mock)
    # Second ref call to get latest commit SHA
    @mock_client.expects(:ref).with(repo_full_name, "heads/main").returns(@first_ref_mock)
    @mock_client.expects(:create_commit).with(
      repo_full_name,
      "Update ingredient: test_ingredient",
      "new_tree_sha",
      "old_sha",
      author: {
        name: @user.name,
        email: @user.email
      }
    ).returns(@new_commit_mock)
    @mock_client.expects(:update_ref).with(
      repo_full_name,
      "heads/main",
      "new_sha"
    )

    result = @service.write_ingredient(ingredient, repo_name: @repo_name)
    assert_equal "new_sha", result.sha
  end

  test "writes recipe to repository" do
    recipe = Data.define(:name, :to_yaml).new(
      name: "test_recipe",
      to_yaml: "# Test recipe YAML"
    )

    repo_full_name = "#{@user.github_username}/#{@repo_name}"

    # Mock the GitHub API calls in sequence
    # First ref call to get base tree SHA
    @mock_client.expects(:ref).with(repo_full_name, "heads/main").returns(@first_ref_mock)
    @mock_client.expects(:commit).with(repo_full_name, "old_sha").returns(@commit_mock)
    @mock_client.expects(:create_tree).with(
      repo_full_name,
      [
        {
          path: "recipes/test_recipe.yml",
          mode: "100644",
          type: "blob",
          content: "# Test recipe YAML"
        }
      ],
      base_tree: "tree_sha"
    ).returns(@tree_mock)
    # Second ref call to get latest commit SHA
    @mock_client.expects(:ref).with(repo_full_name, "heads/main").returns(@first_ref_mock)
    @mock_client.expects(:create_commit).with(
      repo_full_name,
      "Update recipe: test_recipe",
      "new_tree_sha",
      "old_sha",
      author: {
        name: @user.name,
        email: @user.email
      }
    ).returns(@new_commit_mock)
    @mock_client.expects(:update_ref).with(
      repo_full_name,
      "heads/main",
      "new_sha"
    )

    result = @service.write_recipe(recipe, repo_name: @repo_name)
    assert_equal "new_sha", result.sha
  end

  test "name_for_environment returns base name with dev suffix in development" do
    Rails.env.stubs(:development?).returns(true)
    Rails.env.stubs(:test?).returns(false)
    Rails.env.stubs(:production?).returns(false)

    assert_equal "rails-new-io-data-dev", DataRepositoryService.name_for_environment
  end

  test "name_for_environment returns base name in production" do
    Rails.env.stubs(:development?).returns(false)
    Rails.env.stubs(:test?).returns(false)
    Rails.env.stubs(:production?).returns(true)

    assert_equal "rails-new-io-data", DataRepositoryService.name_for_environment
  end

  test "name_for_environment raises error for unknown environment" do
    Rails.env.stubs(:development?).returns(false)
    Rails.env.stubs(:test?).returns(false)
    Rails.env.stubs(:production?).returns(false)
    Rails.stubs(:env).returns(ActiveSupport::StringInquirer.new("staging"))

    error = assert_raises(ArgumentError) do
      DataRepositoryService.name_for_environment
    end
    assert_equal "Unknown Rails environment: staging", error.message
  end
end
