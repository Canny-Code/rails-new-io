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
    mock_client = mock("octokit_client")
    mock_client.expects(:repository?).with("#{@user.github_username}/#{@repo_name}").returns(false)
    mock_client.expects(:create_repository).with(
      @repo_name,
      private: false,
      auto_init: false,
      description: "Repository created via railsnew.io",
      default_branch: "main"
    ).returns(Data.define(:html_url).new(html_url: "https://github.com/#{@user.github_username}/#{@repo_name}"))

    # Expect git operations for creating initial structure
    mock_client.expects(:ref).with("#{@user.github_username}/#{@repo_name}", "heads/main").returns(
      Data.define(:object).new(object: Data.define(:sha).new(sha: "old_sha"))
    )
    mock_client.expects(:commit).with("#{@user.github_username}/#{@repo_name}", "old_sha").returns(
      Data.define(:commit).new(commit: Data.define(:tree).new(tree: Data.define(:sha).new(sha: "tree_sha")))
    )
    mock_client.expects(:create_tree).with(
      "#{@user.github_username}/#{@repo_name}",
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
    ).returns(Data.define(:sha).new(sha: "new_tree_sha"))
    mock_client.expects(:create_commit).with(
      "#{@user.github_username}/#{@repo_name}",
      "Initialize repository structure",
      "new_tree_sha",
      "tree_sha",
      author: {
        name: @user.name,
        email: @user.email
      }
    ).returns(Data.define(:sha).new(sha: "new_sha"))
    mock_client.expects(:update_ref).with(
      "#{@user.github_username}/#{@repo_name}",
      "heads/main",
      "new_sha"
    )

    Octokit::Client.stubs(:new).returns(mock_client)

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
