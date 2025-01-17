require "test_helper"

class DataRepositoryTest < ActiveSupport::TestCase
  fixtures :users, :recipes, :ingredients, :generated_apps

  def setup
    @user = users(:john)
    @repo = DataRepository.new(user: @user)
    @git_mock = mock("git")
    @repo.stubs(:git).returns(@git_mock)
    @git_mock.stubs(:fetch)
    @git_mock.stubs(:reset_hard)
    @git_mock.stubs(:pull)
    @repo.stubs(:remote_repo_exists?).returns(true)  # Prevent actual GitHub API calls
  end

  # Class method tests
  def test_name_for_environment_in_development
    Rails.env.stubs(:development?).returns(true)
    Rails.env.stubs(:test?).returns(false)
    Rails.env.stubs(:production?).returns(false)

    assert_equal "rails-new-io-data-dev", DataRepository.name_for_environment
  end

  def test_name_for_environment_in_test
    Rails.env.stubs(:development?).returns(false)
    Rails.env.stubs(:test?).returns(true)
    Rails.env.stubs(:production?).returns(false)

    assert_equal "rails-new-io-data-test", DataRepository.name_for_environment
  end

  def test_name_for_environment_in_production
    Rails.env.stubs(:development?).returns(false)
    Rails.env.stubs(:test?).returns(false)
    Rails.env.stubs(:production?).returns(true)

    assert_equal "rails-new-io-data", DataRepository.name_for_environment
  end

  def test_name_for_environment_raises_error_for_unknown_environment
    Rails.env.stubs(:development?).returns(false)
    Rails.env.stubs(:test?).returns(false)
    Rails.env.stubs(:production?).returns(false)

    assert_raises(ArgumentError) { DataRepository.name_for_environment }
  end

  # Instance method tests
  def test_writes_ingredient_correctly
    ingredient = ingredients(:rails_authentication)
    base_path = File.join(@repo.send(:repo_path), "ingredients", ingredient.name.parameterize)

    # Expect template.rb write
    template_path = File.join(base_path, "template.rb")
    File.expects(:write).with(template_path, ingredient.template_content)

    # Expect metadata.json write
    metadata_path = File.join(base_path, "metadata.json")
    metadata_content = {
      name: ingredient.name,
      category: ingredient.category,
      description: ingredient.description,
      configures_with: ingredient.configures_with,
      requires: ingredient.requires,
      conflicts_with: ingredient.conflicts_with,
      created_at: ingredient.created_at.iso8601,
      updated_at: ingredient.updated_at.iso8601
    }.to_json
    File.expects(:write).with(metadata_path, metadata_content)

    FileUtils.stubs(:mkdir_p)
    @repo.stubs(:ensure_fresh_repo)
    @repo.stubs(:push_to_remote)

    @repo.write_model(ingredient)
  end

  def test_writes_recipe_correctly
    recipe = recipes(:blog_recipe)
    base_path = File.join(@repo.send(:repo_path), "recipes", recipe.name)

    # Expect metadata.json write
    metadata_path = File.join(base_path, "metadata.json")
    metadata_content = {
      name: recipe.name,
      description: recipe.description,
      cli_flags: recipe.cli_flags,
      created_at: recipe.created_at.iso8601,
      updated_at: recipe.updated_at.iso8601
    }.to_json
    File.expects(:write).with(metadata_path, metadata_content)

    # Expect ingredients.json write
    ingredients_path = File.join(base_path, "ingredients.json")
    ingredients_content = recipe.recipe_ingredients.map { |ri|
      {
        name: ri.ingredient.name,
        position: ri.position,
        configuration: ri.configuration
      }
    }.to_json
    File.expects(:write).with(ingredients_path, ingredients_content)

    FileUtils.stubs(:mkdir_p)
    @repo.stubs(:ensure_fresh_repo)
    @repo.stubs(:push_to_remote)

    @repo.write_model(recipe)
  end

  def test_raises_error_when_trying_to_write_generated_app
    app = generated_apps(:blog_app)

    # Mock git branches and status
    remote_branch = mock("remote_branch")
    remote_branch.stubs(:name).returns("origin/main")
    branches_collection = mock("branches_collection")
    branches_collection.stubs(:remote).returns([ remote_branch ])
    @git_mock.stubs(:branches).returns(branches_collection)

    # Mock git status
    status_mock = mock("status")
    status_mock.stubs(:changed).returns({})
    status_mock.stubs(:added).returns({})
    status_mock.stubs(:deleted).returns({})
    @git_mock.stubs(:status).returns(status_mock)

    # Mock current branch
    current_branch_mock = mock("current_branch")
    current_branch_mock.stubs(:name).returns("main")
    @git_mock.stubs(:branch).returns(current_branch_mock)

    # Mock git operations that happen in ensure_fresh_repo
    @git_mock.stubs(:add).with(all: true)
    @git_mock.stubs(:commit).with("Initialize repository structure")

    # Stub filesystem operations
    FileUtils.stubs(:mkdir_p)
    FileUtils.stubs(:touch)
    File.stubs(:directory?).returns(false)  # This triggers ensure_committable_state
    File.stubs(:write)

    assert_raises(NotImplementedError, "Generated apps are stored in their own repositories") do
      @repo.write_model(app)
    end
  end

  def test_handles_git_push_error
    recipe = recipes(:blog_recipe)
    base_path = File.join(@repo.send(:repo_path), "recipes", recipe.name)

    # Mock git branches and status
    remote_branch = mock("remote_branch")
    remote_branch.stubs(:name).returns("origin/main")
    branches_collection = mock("branches_collection")
    branches_collection.stubs(:remote).returns([ remote_branch ])
    @git_mock.stubs(:branches).returns(branches_collection)

    # Mock current branch
    current_branch_mock = mock("current_branch")
    current_branch_mock.stubs(:name).returns("main")
    @git_mock.stubs(:branch).returns(current_branch_mock)

    # Mock git status
    status_mock = mock("status")
    status_mock.stubs(:changed).returns({ "file" => "status" })
    status_mock.stubs(:added).returns({})
    status_mock.stubs(:deleted).returns({})
    @git_mock.stubs(:status).returns(status_mock)

    # Mock filesystem operations
    FileUtils.stubs(:mkdir_p)
    FileUtils.stubs(:touch)
    File.stubs(:directory?).returns(false)  # This triggers ensure_committable_state
    File.stubs(:exist?).returns(true)
    File.stubs(:write)

    # Mock git operations that happen in ensure_fresh_repo
    @git_mock.stubs(:add).with(all: true)
    @git_mock.stubs(:commit).with("Initialize repository structure")
    @git_mock.expects(:push).with("origin", "main").raises(Git::Error.new("Push failed"))

    # Mock GitHub client
    mock_client = mock("github_client")
    mock_client.stubs(:repository?).returns(true)
    @repo.stubs(:github_client).returns(mock_client)

    # Test that the error is properly propagated
    error = assert_raises(GitRepo::GitSyncError) { @repo.write_model(recipe) }
    assert_equal "Failed to sync changes to GitHub", error.message
  end

  def test_ensure_committable_state_creates_required_structure
    path = @repo.send(:repo_path)

    # Expect directory creation for each required directory
    %w[ingredients recipes].each do |dir|
      dir_path = File.join(path, dir)
      FileUtils.expects(:mkdir_p).with(dir_path)
      FileUtils.expects(:touch).with(File.join(dir_path, ".keep"))
    end

    # Expect README.md creation
    readme_path = File.join(path, "README.md")
    File.expects(:write).with(readme_path, "# Data Repository\nThis repository contains data for rails-new.io")

    @repo.send(:ensure_committable_state)
  end

  def test_ensure_fresh_repo_syncs_with_remote
    # Mock git branches and status
    remote_branch = mock("remote_branch")
    remote_branch.stubs(:name).returns("origin/main")
    branches_collection = mock("branches_collection")
    branches_collection.stubs(:remote).returns([ remote_branch ])
    @git_mock.stubs(:branches).returns(branches_collection)

    # Mock filesystem operations
    File.stubs(:directory?).returns(true)  # Repo exists
    @repo.stubs(:remote_repo_exists?).returns(true)  # Remote exists

    # Expect git operations in sequence
    sequence = sequence("git_sync")
    @git_mock.expects(:fetch).in_sequence(sequence)
    @git_mock.expects(:reset_hard).with("origin/main").in_sequence(sequence)

    @repo.send(:ensure_fresh_repo)
  end

  def test_repository_description_is_specific_to_data_repo
    assert_equal "Data repository for rails-new.io", @repo.send(:repository_description)
  end

  def test_ensure_fresh_repo_commits_and_pushes_when_changes_exist
    # Mock git branches and status
    remote_branch = mock("remote_branch")
    remote_branch.stubs(:name).returns("origin/main")
    branches_collection = mock("branches_collection")
    branches_collection.stubs(:remote).returns([ remote_branch ])
    @git_mock.stubs(:branches).returns(branches_collection)

    # Mock git status to indicate changes
    status_mock = mock("status")
    status_mock.stubs(:changed).returns({ "file1" => "modified" })  # Indicate changes
    status_mock.stubs(:added).returns({})    # No additions
    status_mock.stubs(:deleted).returns({})
    @git_mock.stubs(:status).returns(status_mock)

    # Mock current branch
    current_branch_mock = mock("current_branch")
    current_branch_mock.stubs(:name).returns("main")
    @git_mock.stubs(:branch).returns(current_branch_mock)

    # Mock filesystem operations
    FileUtils.stubs(:mkdir_p)
    FileUtils.stubs(:touch)
    File.stubs(:directory?).returns(false)  # This triggers ensure_committable_state
    File.stubs(:write)
    @repo.stubs(:remote_repo_exists?).returns(true)  # Remote exists

    # Expect git operations
    @git_mock.expects(:add).with(all: true)
    @git_mock.expects(:commit).with("Initialize repository structure")
    @git_mock.expects(:push).with("origin", "main")

    @repo.send(:ensure_fresh_repo)
  end

  def test_ensure_fresh_repo_skips_commit_when_no_changes
    # Mock git branches and status
    remote_branch = mock("remote_branch")
    remote_branch.stubs(:name).returns("origin/main")
    branches_collection = mock("branches_collection")
    branches_collection.stubs(:remote).returns([ remote_branch ])
    @git_mock.stubs(:branches).returns(branches_collection)

    # Mock git status to indicate no changes
    status_mock = mock("status")
    status_mock.stubs(:changed).returns({})  # No changes
    status_mock.stubs(:added).returns({})    # No additions
    status_mock.stubs(:deleted).returns({})
    @git_mock.stubs(:status).returns(status_mock)

    # Mock current branch
    current_branch_mock = mock("current_branch")
    current_branch_mock.stubs(:name).returns("main")
    @git_mock.stubs(:branch).returns(current_branch_mock)

    # Mock filesystem operations
    FileUtils.stubs(:mkdir_p).returns(true)  # Return true for all mkdir_p calls
    FileUtils.stubs(:touch).returns(true)    # Return true for all touch calls
    File.stubs(:directory?).returns(false)   # Trigger initialization
    File.stubs(:write).returns(true)         # Allow README.md creation

    # Expect git operations
    @git_mock.expects(:add).with(all: true)  # add is still called
    @git_mock.expects(:commit).never         # but commit should never happen
    @git_mock.expects(:push).never           # and push should never happen

    @repo.send(:ensure_fresh_repo)
  end

  def test_ensure_fresh_repo_when_repo_doesnt_exist_locally
    # Mock that repo doesn't exist locally
    File.stubs(:exist?).with(@repo.send(:repo_path)).returns(false)
    File.stubs(:directory?).returns(true)  # For other directory checks

    # Mock git branches and status
    remote_branch = mock("remote_branch")
    remote_branch.stubs(:name).returns("origin/main")
    branches_collection = mock("branches_collection")
    branches_collection.stubs(:remote).returns([ remote_branch ])
    @git_mock.stubs(:branches).returns(branches_collection)

    # Mock git status
    status_mock = mock("status")
    status_mock.stubs(:changed).returns({})
    status_mock.stubs(:added).returns({})
    status_mock.stubs(:deleted).returns({})
    @git_mock.stubs(:status).returns(status_mock)

    sequence = sequence("repo_init")

    # Case 1: Remote exists
    @repo.unstub(:remote_repo_exists?)  # Remove the default stub
    @repo.stubs(:remote_repo_exists?).returns(true)

    # Expect clone operation
    Git.expects(:clone).with(
      "https://#{@user.github_token}@github.com/#{@user.github_username}/#{DataRepository.name_for_environment}.git",
      DataRepository.name_for_environment,
      path: File.dirname(@repo.send(:repo_path))
    ).in_sequence(sequence)

    # Expect git open after clone
    Git.expects(:open).with(@repo.send(:repo_path)).returns(@git_mock).in_sequence(sequence)

    @repo.send(:ensure_fresh_repo)

    # Case 2: Remote doesn't exist
    @repo.unstub(:remote_repo_exists?)  # Remove previous stub
    @repo.stubs(:remote_repo_exists?).returns(false)

    # Expect local repo creation and setup
    @repo.expects(:create_local_repo).in_sequence(sequence)
    @repo.expects(:ensure_github_repo_exists).in_sequence(sequence)
    @repo.expects(:setup_remote).in_sequence(sequence)
    @repo.expects(:push_to_remote).in_sequence(sequence)

    @repo.send(:ensure_fresh_repo)
  end

  def test_template_path_returns_correct_path
    ingredient = ingredients(:rails_authentication)
    expected_path = File.join(@repo.send(:repo_path), "ingredients", ingredient.name.parameterize, "template.rb")
    assert_equal expected_path, @repo.template_path(ingredient)
  end

  private

  def stub_filesystem_operations
    @repo.stubs(:ensure_fresh_repo)
    @repo.stubs(:push_to_remote)
    FileUtils.stubs(:mkdir_p)
    FileUtils.stubs(:touch)
  end

  def assert_path_written(relative_path, expected_content)
    full_path = File.join(@repo.send(:repo_path), relative_path)
    assert File.stubs(:write).with(full_path, expected_content.to_json).once
  end
end
