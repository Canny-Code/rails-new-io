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
    @git_mock.stubs(:push)
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
  def test_writes_generated_app_correctly
    app = generated_apps(:blog_app)
    expected_path = File.join(@repo.send(:repo_path), "generated_apps", app.id.to_s, "current_state.json")
    expected_content = {
      name: app.name,
      recipe_id: app.recipe_id,
      configuration: app.configuration_options
    }.to_json

    File.expects(:write).with(expected_path, expected_content)

    # Also expect the history.json write
    history_path = File.join(@repo.send(:repo_path), "generated_apps", app.id.to_s, "history.json")
    File.expects(:write).with(history_path, app.app_changes.map(&:to_git_format).to_json)

    FileUtils.stubs(:mkdir_p)
    @repo.stubs(:ensure_fresh_repo)
    @repo.stubs(:push_to_remote)

    @repo.write_model(app)
  end

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
      description: ingredient.description,
      conflicts_with: ingredient.conflicts_with,
      requires: ingredient.requires,
      configures_with: ingredient.configures_with
    }.to_json
    File.expects(:write).with(metadata_path, metadata_content)

    FileUtils.stubs(:mkdir_p)
    @repo.stubs(:ensure_fresh_repo)
    @repo.stubs(:push_to_remote)

    @repo.write_model(ingredient)
  end

  def test_writes_recipe_correctly
    recipe = recipes(:blog_recipe)
    base_path = File.join(@repo.send(:repo_path), "recipes", recipe.id.to_s)

    # Expect manifest.json write
    manifest_path = File.join(base_path, "manifest.json")
    manifest_content = {
      name: recipe.name,
      cli_flags: recipe.cli_flags,
      ruby_version: recipe.ruby_version,
      rails_version: recipe.rails_version
    }.to_json
    File.expects(:write).with(manifest_path, manifest_content)

    # Expect ingredients.json write
    ingredients_path = File.join(base_path, "ingredients.json")
    ingredients_content = recipe.recipe_ingredients.order(:position).map(&:to_git_format).to_json
    File.expects(:write).with(ingredients_path, ingredients_content)

    FileUtils.stubs(:mkdir_p)
    @repo.stubs(:ensure_fresh_repo)
    @repo.stubs(:push_to_remote)

    @repo.write_model(recipe)
  end

  def test_handles_git_push_error
    recipe = recipes(:blog_recipe)
    base_path = File.join(@repo.send(:repo_path), "recipes", recipe.id.to_s)

    # Stub the file writes
    manifest_path = File.join(base_path, "manifest.json")
    ingredients_path = File.join(base_path, "ingredients.json")
    File.stubs(:write).with(manifest_path, anything)
    File.stubs(:write).with(ingredients_path, anything)

    FileUtils.stubs(:mkdir_p)
    @repo.stubs(:ensure_fresh_repo)
    @repo.unstub(:push_to_remote)  # We want the real push_to_remote to trigger the error
    @git_mock.stubs(:push).raises(Git::Error.new("Push failed"))

    assert_raises(GitRepo::GitSyncError) { @repo.write_model(recipe) }
  end

  def test_ensure_committable_state_creates_required_structure
    path = @repo.send(:repo_path)

    # Expect directory creation for each required directory
    %w[generated_apps ingredients recipes].each do |dir|
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
    sequence = sequence("git_sync")

    @git_mock.expects(:fetch).in_sequence(sequence)
    @git_mock.expects(:reset_hard).with("origin/main").in_sequence(sequence)
    @git_mock.expects(:pull).in_sequence(sequence)

    @repo.send(:ensure_fresh_repo)
  end

  def test_repository_description_is_specific_to_data_repo
    assert_equal "Data repository for rails-new.io", @repo.send(:repository_description)
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
