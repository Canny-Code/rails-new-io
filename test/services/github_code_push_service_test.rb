require "test_helper"

class GithubCodePushServiceTest < ActiveSupport::TestCase
  def setup
    @user = users(:john)
    @user.stubs(:github_token).returns("fake-token")
    @recipe = recipes(:blog_recipe)
    @temp_dir = Dir.mktmpdir

    # Stub GitRepo to avoid GitHub API calls
    @git_repo = mock("GitRepo")
    @git_repo.stubs(:commit_changes)
    GitRepo.stubs(:new).returns(@git_repo)

    @generated_app = GeneratedApp.create!(
      name: "test-app-123",
      user: @user,
      recipe: @recipe,
      ruby_version: "3.2.0",
      rails_version: "7.1.0",
      selected_gems: [],
      configuration_options: {},
      source_path: @temp_dir,
      github_repo_name: "test-app-123"
    )

    # Replace existing app_status with our test one
    @generated_app.app_status.destroy!
    @app_status = @generated_app.create_app_status!(
      status: "generating",
      started_at: Time.current,
      status_history: []
    )

    @service = GithubCodePushService.new(@generated_app)
  end

  def teardown
    # Clean up temp directory
    if @temp_dir && Dir.exist?(@temp_dir)
      FileUtils.rm_rf(@temp_dir)
    end

    if @generated_app
      ActiveRecord::Base.transaction do
        # Delete associated records first
        AppGeneration::LogEntry.where(generated_app_id: @generated_app.id).delete_all
        @generated_app.app_status&.delete

        # Update non-null fields with placeholder values before deletion
        @generated_app.update_columns(
          source_path: nil,
          github_repo_url: nil
        )
      end
    end
  end

  test "raises FileSystemError when IO operation fails" do
    error_message = "Permission denied"
    # Create the directory first so we get past the existence check
    FileUtils.mkdir_p(@generated_app.source_path)
    @service.stubs(:push_code).raises(GithubCodePushService::FileSystemError.new(error_message))

    error = assert_raises(GithubCodePushService::FileSystemError) do
      @service.execute
    end

    assert_equal "File system error: #{error_message}", error.message
    assert @generated_app.app_status.failed?
    assert_equal error_message, @generated_app.app_status.error_message
  end

  test "raises InvalidStateError when app is not in generating state" do
    @generated_app.app_status.update!(status: :pending)
    # Create the directory so we get past the existence check
    FileUtils.mkdir_p(@generated_app.source_path)

    error = assert_raises(GithubCodePushService::InvalidStateError) do
      @service.execute
    end

    assert_equal GithubCodePushService::INVALID_STATE_MESSAGE, error.message
  end

  test "executes full process successfully" do
    # Use the existing app but update its attributes
    @generated_app.update!(
      github_repo_name: @generated_app.name  # Only set the repo name, let service set the URL
    )
    @app_status.update!(status: :generating)

    # Set up the github token for the user
    @user.define_singleton_method(:github_token) { "fake-token" }

    # Create the app directory structure
    app_dir = File.join(@temp_dir, @generated_app.name)
    FileUtils.mkdir_p(app_dir)

    # Create a dummy file to commit
    File.write(File.join(app_dir, "README.md"), "# #{@generated_app.name}")

    # Initialize git repo
    Git.init(app_dir)

    # Mock Git operations
    git_mock = mock("git")
    Git.expects(:open).with("#{@temp_dir}/#{@generated_app.name}").returns(git_mock)

    git_mock.expects(:config).with("user.name", "John Doe")
    git_mock.expects(:config).with("user.email", "john@example.com")
    git_mock.expects(:add).with(all: true)
    git_mock.expects(:commit).with("Initial commit")
    git_mock.expects(:add_remote).with("origin", kind_of(String))
    git_mock.expects(:push).with("origin", "main")

    # Execute
    @service.execute

    # Transition through the remaining states
    @generated_app.start_ci!
    @generated_app.mark_as_completed!

    # Final assertions
    @generated_app.reload
    expected_url = "https://github.com/#{@user.github_username}/#{@generated_app.name}"
    assert_equal expected_url, @generated_app.github_repo_url
    assert @generated_app.app_status.completed?
  end

  test "push_code configures_git_and_pushes_to_remote" do
    # Use saas_starter which belongs to John
    @generated_app = generated_apps(:saas_starter)
    @user = @generated_app.user
    @user.define_singleton_method(:github_token) { "fake-token" }

    # Create the directory structure
    app_dir = File.join(@temp_dir, @generated_app.name)
    FileUtils.mkdir_p(app_dir)
    Git.init(app_dir)

    # Set the source path to the parent directory
    @generated_app.update!(source_path: @temp_dir)
    @service = GithubCodePushService.new(@generated_app)

    git_mock = mock("git")
    Git.expects(:open).with("#{@temp_dir}/#{@generated_app.name}").returns(git_mock)

    # Use John's fixture values
    git_mock.expects(:config).with("user.name", "John Doe")
    git_mock.expects(:config).with("user.email", "john@example.com")
    git_mock.expects(:add).with(all: true)
    git_mock.expects(:commit).with("Initial commit")
    git_mock.expects(:add_remote).with("origin", kind_of(String))
    git_mock.expects(:push).with("origin", "main")

    @service.send(:push_code)
  end

  test "push_code raises GitError when git operations fail" do
    @generated_app = generated_apps(:saas_starter)
    @user = @generated_app.user
    @user.stubs(:github_token).returns("fake-token")

    # Create directory structure but don't init git
    app_dir = File.join(@temp_dir, @generated_app.name)
    FileUtils.mkdir_p(app_dir)

    @generated_app.update!(source_path: @temp_dir)
    @service = GithubCodePushService.new(@generated_app)

    Git.stubs(:open).raises(Git::Error.new("Git error"))

    assert_raises(GithubCodePushService::GitError) do
      @service.execute
    end
  end

  test "handles unexpected errors with standard error handler" do
    @generated_app = generated_apps(:saas_starter)
    @user = @generated_app.user
    @user.define_singleton_method(:github_token) { "fake-token" }

    # Create directory structure
    app_dir = File.join(@temp_dir, @generated_app.name)
    FileUtils.mkdir_p(app_dir)

    @generated_app.update!(source_path: @temp_dir)
    @generated_app.app_status.update!(status: :generating)
    @service = GithubCodePushService.new(@generated_app)

    # Simulate an unexpected error
    Git.stubs(:open).raises(StandardError.new("Unexpected error"))

    error = assert_raises(GithubCodePushService::Error) do
      @service.execute
    end

    assert_equal "Unexpected error", error.message
    assert @generated_app.reload.app_status.failed?
  end

  test "raises FileSystemError when source directory does not exist" do
    # Use a path that definitely doesn't exist
    nonexistent_path = Rails.root.join("tmp", "definitely_does_not_exist_#{SecureRandom.hex}").to_s
    @generated_app.update!(source_path: nonexistent_path)

    error = assert_raises(GithubCodePushService::FileSystemError) do
      @service.execute
    end

    assert_match "File system error: Source directory does not exist", error.message
    assert @generated_app.reload.app_status.failed?
  end
end
