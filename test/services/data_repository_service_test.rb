require "test_helper"

class DataRepositoryServiceTest < ActiveSupport::TestCase
  def setup
    @user = users(:john)
    @user.stubs(:github_token).returns("fake-token")
    @service = DataRepositoryService.new(user: @user)
    @repository_name = DataRepositoryService.name_for_environment
  end

  test "initializes repository with correct structure" do
    response = Data.define(:html_url).new(html_url: "https://github.com/#{@user.github_username}/#{@repository_name}")

    mock_client = mock("octokit_client")
    mock_client.expects(:repository?).with("#{@user.github_username}/#{@repository_name}").returns(false)
    mock_client.expects(:create_repository).with(@repository_name, {
      private: false,
      auto_init: true,
      description: "Data repository for railsnew.io",
      default_branch: "main"
    }).returns(response)

    # Expect initial structure commit
    mock_client.expects(:ref).with("#{@user.github_username}/#{@repository_name}", "heads/main").returns(
      Data.define(:object).new(object: Data.define(:sha).new(sha: "old_sha"))
    )
    mock_client.expects(:commit).with("#{@user.github_username}/#{@repository_name}", "old_sha").returns(
      Data.define(:commit).new(commit: Data.define(:tree).new(tree: Data.define(:sha).new(sha: "tree_sha")))
    )
    mock_client.expects(:create_tree).with(
      "#{@user.github_username}/#{@repository_name}",
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
      "#{@user.github_username}/#{@repository_name}",
      "Initialize repository structure",
      "new_tree_sha",
      "tree_sha",
      author: {
        name: @user.github_username,
        email: "#{@user.github_username}@users.noreply.github.com"
      }
    ).returns(Data.define(:sha).new(sha: "new_sha"))
    mock_client.expects(:update_ref).with(
      "#{@user.github_username}/#{@repository_name}",
      "heads/main",
      "new_sha"
    )

    Octokit::Client.stubs(:new).returns(mock_client)

    result = @service.initialize_repository
    assert_equal response.html_url, result.html_url
  end

  test "writes ingredient to repository" do
    ingredient = Data.define(:name, :template_content).new(
      name: "test_ingredient",
      template_content: "# Test template"
    )

    mock_client = mock("octokit_client")
    mock_client.expects(:ref).with("#{@user.github_username}/#{@repository_name}", "heads/main").returns(
      Data.define(:object).new(object: Data.define(:sha).new(sha: "old_sha"))
    )
    mock_client.expects(:commit).with("#{@user.github_username}/#{@repository_name}", "old_sha").returns(
      Data.define(:commit).new(commit: Data.define(:tree).new(tree: Data.define(:sha).new(sha: "tree_sha")))
    )
    mock_client.expects(:create_tree).with(
      "#{@user.github_username}/#{@repository_name}",
      [
        {
          path: "ingredients/#{ingredient.name}/template.rb",
          mode: "100644",
          type: "blob",
          content: ingredient.template_content
        }
      ],
      base_tree: "tree_sha"
    ).returns(Data.define(:sha).new(sha: "new_tree_sha"))
    mock_client.expects(:create_commit).with(
      "#{@user.github_username}/#{@repository_name}",
      "Update ingredient: #{ingredient.name}",
      "new_tree_sha",
      "tree_sha",
      author: {
        name: @user.github_username,
        email: "#{@user.github_username}@users.noreply.github.com"
      }
    ).returns(Data.define(:sha).new(sha: "new_sha"))
    mock_client.expects(:update_ref).with(
      "#{@user.github_username}/#{@repository_name}",
      "heads/main",
      "new_sha"
    )

    Octokit::Client.stubs(:new).returns(mock_client)

    @service.write_ingredient(ingredient, repo_name: @repository_name)
  end

  test "writes recipe to repository" do
    recipe = Data.define(:name, :to_yaml).new(
      name: "test_recipe",
      to_yaml: "# Test recipe YAML"
    )

    mock_client = mock("octokit_client")
    mock_client.expects(:ref).with("#{@user.github_username}/#{@repository_name}", "heads/main").returns(
      Data.define(:object).new(object: Data.define(:sha).new(sha: "old_sha"))
    )
    mock_client.expects(:commit).with("#{@user.github_username}/#{@repository_name}", "old_sha").returns(
      Data.define(:commit).new(commit: Data.define(:tree).new(tree: Data.define(:sha).new(sha: "tree_sha")))
    )
    mock_client.expects(:create_tree).with(
      "#{@user.github_username}/#{@repository_name}",
      [
        {
          path: "recipes/#{recipe.name}.yml",
          mode: "100644",
          type: "blob",
          content: recipe.to_yaml
        }
      ],
      base_tree: "tree_sha"
    ).returns(Data.define(:sha).new(sha: "new_tree_sha"))
    mock_client.expects(:create_commit).with(
      "#{@user.github_username}/#{@repository_name}",
      "Update recipe: #{recipe.name}",
      "new_tree_sha",
      "tree_sha",
      author: {
        name: @user.github_username,
        email: "#{@user.github_username}@users.noreply.github.com"
      }
    ).returns(Data.define(:sha).new(sha: "new_sha"))
    mock_client.expects(:update_ref).with(
      "#{@user.github_username}/#{@repository_name}",
      "heads/main",
      "new_sha"
    )

    Octokit::Client.stubs(:new).returns(mock_client)

    @service.write_recipe(recipe, repo_name: @repository_name)
  end
end
