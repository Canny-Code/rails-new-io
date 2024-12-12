require "test_helper"

class GitRepoTest < ActiveSupport::TestCase
  setup do
    @user = users(:jane)
    # Define github_token method to bypass encryption
    @user.define_singleton_method(:github_token) { "fake-token" }

    @repo_name = "rails-new-io-data-test"
    @repo_path = Rails.root.join("tmp", "git_repos", @user.id.to_s, @repo_name)

    # Ensure parent directory exists and is empty
    FileUtils.rm_rf(File.dirname(@repo_path))
    FileUtils.mkdir_p(File.dirname(@repo_path))

    # Create a mock git object
    @git = mock("git")
    @git.stubs(:config)
    @git.stubs(:add)
    @git.stubs(:commit)
    Git.stubs(:init).returns(@git)
    Git.stubs(:open).returns(@git)

    # Stub file operations
    FileUtils.stubs(:mkdir_p).returns(true)
    File.stubs(:write).returns(true)
    File.stubs(:exist?).returns(true)
    File.stubs(:read).returns("{}")
    JSON.stubs(:parse).returns({})

    # Stub GitHub API calls
    GitRepo.any_instance.stubs(:remote_repo_exists?).returns(false)
    GitRepo.any_instance.stubs(:create_github_repo).returns(true)
    GitRepo.any_instance.stubs(:create_initial_structure).returns(true)
    GitRepo.any_instance.stubs(:setup_remote).returns(true)

    @repo = GitRepo.new(user: @user, repo_name: @repo_name)
  end

  teardown do
    # Clean up after each test
    FileUtils.rm_rf(@repo_path) if File.exist?(@repo_path)
    FileUtils.rm_rf(File.dirname(@repo_path)) if File.exist?(File.dirname(@repo_path))

    # Clean up any remaining stubs
    GitRepo.any_instance.unstub(:remote_repo_exists?)
    GitRepo.any_instance.unstub(:create_github_repo)
    GitRepo.any_instance.unstub(:create_initial_structure)
    GitRepo.any_instance.unstub(:setup_remote)
    Rails.unstub(:env) if Rails.respond_to?(:env) && Rails.env.is_a?(Mocha::Mock)
  end

  test "initializes with user and repo name" do
    assert_equal @user, @repo.instance_variable_get(:@user)
    assert_equal @repo_name, @repo.instance_variable_get(:@repo_name)
    expected_path = Rails.root.join("tmp", "git_repos", @user.id.to_s, @repo_name)
    assert_equal expected_path, @repo.instance_variable_get(:@repo_path)
  end

  test "writes generated app to repo" do
    app = generated_apps(:blog_app)
    path = File.join(@repo_path, "generated_apps", app.id.to_s)

    # Expect git operations
    @git.expects(:fetch)
    @git.expects(:reset_hard).with("origin/main")
    @git.expects(:pull)
    @git.expects(:push).with("origin", "main")

    # Expect file operations
    FileUtils.expects(:mkdir_p).with(path)
    File.expects(:write).with(
      File.join(path, "current_state.json"),
      JSON.pretty_generate({
        name: app.name,
        recipe_id: app.recipe_id,
        configuration: app.configuration_options
      })
    )
    File.expects(:write).with(
      File.join(path, "history.json"),
      JSON.pretty_generate(app.app_changes.map(&:to_git_format))
    )

    @repo.write_model(app)
  end

  test "writes ingredient to repo" do
    ingredient = ingredients(:rails_authentication)
    path = File.join(@repo_path, "ingredients", ingredient.name.parameterize)

    # Expect git operations
    @git.expects(:fetch)
    @git.expects(:reset_hard).with("origin/main")
    @git.expects(:pull)
    @git.expects(:push).with("origin", "main")

    # Expect file operations
    FileUtils.expects(:mkdir_p).with(path)
    File.expects(:write).with(
      File.join(path, "template.rb"),
      ingredient.template_content
    )
    File.expects(:write).with(
      File.join(path, "metadata.json"),
      JSON.pretty_generate({
        name: ingredient.name,
        description: ingredient.description,
        conflicts_with: ingredient.conflicts_with,
        requires: ingredient.requires,
        configures_with: ingredient.configures_with
      })
    )

    @repo.write_model(ingredient)
  end

  test "writes recipe to repo" do
    recipe = recipes(:blog_recipe)
    path = File.join(@repo_path, "recipes", recipe.id.to_s)

    # Expect git operations
    @git.expects(:fetch)
    @git.expects(:reset_hard).with("origin/main")
    @git.expects(:pull)
    @git.expects(:push).with("origin", "main")

    # Expect file operations
    FileUtils.expects(:mkdir_p).with(path)
    File.expects(:write).with(
      File.join(path, "manifest.json"),
      JSON.pretty_generate({
        name: recipe.name,
        cli_flags: recipe.cli_flags,
        ruby_version: recipe.ruby_version,
        rails_version: recipe.rails_version
      })
    )
    File.expects(:write).with(
      File.join(path, "ingredients.json"),
      JSON.pretty_generate(recipe.recipe_ingredients.order(:position).map(&:to_git_format))
    )

    @repo.write_model(recipe)
  end

  test "handles git push errors" do
    recipe = recipes(:blog_recipe)
    path = File.join(@repo_path, "recipes", recipe.id.to_s)

    # Expect git operations
    @git.expects(:fetch)
    @git.expects(:reset_hard).with("origin/main")
    @git.expects(:pull)
    @git.expects(:push).with("origin", "main").raises(Git::Error.new("push failed"))

    # Expect file operations (these need to succeed before the push fails)
    FileUtils.expects(:mkdir_p).with(path)
    File.expects(:write).with(
      File.join(path, "manifest.json"),
      JSON.pretty_generate({
        name: recipe.name,
        cli_flags: recipe.cli_flags,
        ruby_version: recipe.ruby_version,
        rails_version: recipe.rails_version
      })
    )
    File.expects(:write).with(
      File.join(path, "ingredients.json"),
      JSON.pretty_generate(recipe.recipe_ingredients.order(:position).map(&:to_git_format))
    )

    assert_raises(GitRepo::GitSyncError) do
      @repo.write_model(recipe)
    end
  end

  test "uses correct repo name suffix in development environment" do
    github_client = Minitest::Mock.new
    GitRepo.any_instance.unstub(:remote_repo_exists?)
    GitRepo.any_instance.stubs(:create_github_repo).returns(true)
    GitRepo.any_instance.stubs(:create_initial_structure).returns(true)
    GitRepo.any_instance.stubs(:setup_remote).returns(true)

    rails_env = mock
    rails_env.stubs(:development?).returns(true)
    rails_env.stubs(:test?).returns(false)
    rails_env.stubs(:production?).returns(false)
    Rails.stubs(:env).returns(rails_env)

    Octokit::Client.stub :new, github_client do
      github_client.expect :repository?, false, [ "#{@user.github_username}/rails-new-io-data-dev" ]
      repo = GitRepo.new(user: @user, repo_name: @repo_name)
      assert_equal "rails-new-io-data-dev", repo.send(:repo_name)
      github_client.verify
    end
  end

  test "uses correct repo name suffix in test environment" do
    github_client = Minitest::Mock.new
    GitRepo.any_instance.unstub(:remote_repo_exists?)
    GitRepo.any_instance.stubs(:create_github_repo).returns(true)
    GitRepo.any_instance.stubs(:create_initial_structure).returns(true)
    GitRepo.any_instance.stubs(:setup_remote).returns(true)

    rails_env = mock
    rails_env.stubs(:development?).returns(false)
    rails_env.stubs(:test?).returns(true)
    rails_env.stubs(:production?).returns(false)
    rails_env.stubs(:to_s).returns("test")
    Rails.stubs(:env).returns(rails_env)

    Octokit::Client.stub :new, github_client do
      github_client.expect :repository?, false, [ "#{@user.github_username}/rails-new-io-data-test" ]
      repo = GitRepo.new(user: @user, repo_name: @repo_name)
      assert_equal "rails-new-io-data-test", repo.send(:repo_name)
      github_client.verify
    end
  end

  test "uses base repo name in production environment" do
    # First clear the existing instance to avoid multiple method calls
    @repo = nil

    # Remove all existing stubs
    GitRepo.any_instance.unstub(:remote_repo_exists?)
    GitRepo.any_instance.unstub(:create_github_repo)
    GitRepo.any_instance.unstub(:create_initial_structure)
    GitRepo.any_instance.unstub(:setup_remote)

    Mocha::Configuration.override(stubbing_non_public_method: :allow) do
      # Set up production environment in a block to ensure cleanup
      rails_env = mock
      rails_env.stubs(:development?).returns(false)
      rails_env.stubs(:test?).returns(false)
      rails_env.stubs(:production?).returns(true)
      Rails.stubs(:env).returns(rails_env)

      # Mock GitHub client for this specific test
      github_client = Minitest::Mock.new
      github_client.expect :repository?, false, [ "#{@user.github_username}/rails-new-io-data" ]

      # Re-stub necessary methods after the repository check
      GitRepo.any_instance.stubs(:create_github_repo).returns(true)
      GitRepo.any_instance.stubs(:create_initial_structure).returns(true)
      GitRepo.any_instance.stubs(:setup_remote).returns(true)

      Octokit::Client.stub :new, github_client do
        repo = GitRepo.new(user: @user, repo_name: @repo_name)
        assert_equal "rails-new-io-data", repo.send(:repo_name)
        github_client.verify
      end
    end
  end

  test "raises error for unknown Rails environment" do
    GitRepo.any_instance.unstub(:remote_repo_exists?)
    GitRepo.any_instance.stubs(:create_github_repo).returns(true)
    GitRepo.any_instance.stubs(:create_initial_structure).returns(true)
    GitRepo.any_instance.stubs(:setup_remote).returns(true)

    rails_env = mock
    rails_env.stubs(:development?).returns(false)
    rails_env.stubs(:test?).returns(false)
    rails_env.stubs(:production?).returns(false)
    rails_env.stubs(:to_s).returns("staging")
    Rails.stubs(:env).returns(rails_env)

    assert_raises(ArgumentError, "Unknown Rails environment: staging") do
      GitRepo.new(user: @user, repo_name: @repo_name)
    end
  end

  test "handles GitHub API errors when checking repository existence" do
    # Clear the stub for remote_repo_exists? since we want to test it
    GitRepo.any_instance.unstub(:remote_repo_exists?)

    # Create a test logger
    test_logger = Class.new do
      attr_reader :messages
      def initialize
        @messages = []
      end

      def error(message)
        @messages << message
      end
    end.new

    Rails.stubs(:logger).returns(test_logger)

    # Create a client that raises an error
    error = Octokit::Error.new(
      method: :get,
      url: "https://api.github.com/repos/#{@user.github_username}/rails-new-io-data-test",
      status: 401,
      response_headers: {},
      body: { message: "Bad credentials" }
    )

    mock_client = mock
    mock_client.expects(:repository?).raises(error)

    # Test error handling
    @repo.instance_variable_set(:@github_client, mock_client)
    result = @repo.send(:remote_repo_exists?)

    # Verify behavior
    assert_equal false, result
    assert_equal 1, test_logger.messages.size
    assert_equal(
      "Failed to check GitHub repository: GET https://api.github.com/repos/jane_smith/rails-new-io-data-test: 401 - Bad credentials",
      test_logger.messages.first
    )
  end
end

class GitRepoCreateTest < ActiveSupport::TestCase
  test "creates github repository with correct parameters" do
    # Create a test user
    test_user = User.new(github_username: "test_user", github_token: "fake-token")

    # Create a repo instance WITHOUT initialization
    repo = Class.new(GitRepo) do
      def initialize(user:)
        @user = user
      end
    end.new(user: test_user)

    # Set up the test expectations
    mock_client = mock("github_client")
    mock_client.expects(:create_repository).with(
      "rails-new-io-data-test",
      private: false,
      description: "Data repository for rails-new.io"
    ).returns(true)

    # Inject our dependencies
    repo.stubs(:repo_name).returns("rails-new-io-data-test")
    repo.instance_variable_set(:@github_client, mock_client)

    # Test just the create_github_repo method
    repo.send(:create_github_repo)
  end
end

class GitRepoStructureTest < ActiveSupport::TestCase
  setup do
    @user = users(:jane)
    @user.define_singleton_method(:github_token) { "fake-token" }
    @repo_name = "rails-new-io-data-test"
    @repo_path = Rails.root.join("tmp", "git_repos", @user.id.to_s, @repo_name)
  end

  test "creates initial repository structure" do
    # Create a minimal repo instance with readme_content method
    repo = Class.new(GitRepo) do
      def initialize(user:, repo_path:)
        @user = user
        @repo_path = repo_path
      end

      private

      def readme_content
        "# Data Repository\nThis repository contains data for rails-new.io"
      end
    end.new(user: @user, repo_path: @repo_path)

    # Mock Git operations
    git = mock("git")
    git.expects(:add).with(all: true)
    git.expects(:commit).with("Initial commit")
    repo.stubs(:git).returns(git)

    # Mock file operations
    FileUtils.expects(:mkdir_p).with(File.join(@repo_path, "generated_apps"))
    FileUtils.expects(:mkdir_p).with(File.join(@repo_path, "ingredients"))
    FileUtils.expects(:mkdir_p).with(File.join(@repo_path, "recipes"))
    File.expects(:write).with(
      File.join(@repo_path, "README.md"),
      "# Data Repository\nThis repository contains data for rails-new.io"
    )

    # Test just the create_initial_structure method
    repo.send(:create_initial_structure)
  end
end

class GitRepoRemoteTest < ActiveSupport::TestCase
  setup do
    @user = users(:jane)
    @user.define_singleton_method(:github_token) { "fake-token" }
    @repo_name = "rails-new-io-data-test"
    @repo_path = Rails.root.join("tmp", "git_repos", @user.id.to_s, @repo_name)
  end

  test "sets up git remote with correct URL" do
    # Create a minimal repo instance
    repo = Class.new(GitRepo) do
      def initialize(user:, repo_path:)
        @user = user
        @repo_path = repo_path
      end

      def repo_name
        "rails-new-io-data-test"
      end
    end.new(user: @user, repo_path: @repo_path)

    # Mock Git operations
    git = mock("git")
    git.expects(:add_remote).with(
      "origin",
      "https://fake-token@github.com/#{@user.github_username}/rails-new-io-data-test.git"
    )
    repo.stubs(:git).returns(git)

    # Test the setup_remote method
    repo.send(:setup_remote)
  end
end
