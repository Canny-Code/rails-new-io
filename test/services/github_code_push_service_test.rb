require "test_helper"

class GithubCodePushServiceTest < ActiveSupport::TestCase
  def setup
    @user = users(:john)
    @generated_app = generated_apps(:blog_app)
    @generated_app.create_app_status!
    @generated_app.app_status.update!(status: :generating)
    @temp_dir = Dir.mktmpdir
    @generated_app.update!(source_path: @temp_dir)
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

    error = assert_raises(GithubCodePushService::InvalidStateError) do
      @service.execute
    end

    assert_equal GithubCodePushService::INVALID_STATE_MESSAGE, error.message
  end

  test "executes full process successfully" do
    # Create the app directory structure
    app_dir = File.join(@temp_dir, @generated_app.name)
    FileUtils.mkdir_p(app_dir)

    # Create a dummy file to commit
    File.write(File.join(app_dir, "README.md"), "# #{@generated_app.name}")

    # Initialize git repo (since Rails would have done this)
    Git.init(app_dir)

    # Ensure app is in the correct initial state
    @generated_app.app_status.update!(status: :generating)

    # Get the actual GitHub username from the generated app's user
    github_username = @generated_app.user.github_username

    # Stub the push_code method to simulate successful execution
    @service.expects(:push_code).once do
      @generated_app.update!(github_repo_url: "https://github.com/#{github_username}/#{@generated_app.name}")
      @generated_app.push_to_github!

      # Check status immediately after push_to_github!
      assert_equal "pushing_to_github", @generated_app.app_status.reload.status,
        "Status should be pushing_to_github immediately after push_to_github!"

      true
    end

    # Execute
    @service.execute

    # Final assertions
    @generated_app.reload
    expected_url = "https://github.com/#{github_username}/#{@generated_app.name}"
    actual_url = @generated_app.github_repo_url
    assert_equal expected_url, actual_url,
      "Expected GitHub URL to be #{expected_url}, but was #{actual_url}"
    assert @generated_app.app_status.completed?,
      "Expected final status to be completed, but was #{@generated_app.app_status.status}"
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
    @user.define_singleton_method(:github_token) { "fake-token" }

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
    # Create a fresh app instead of using fixture
    @generated_app = GeneratedApp.create!(
      name: "test-app-#{SecureRandom.hex(4)}",
      user: users(:john),
      ruby_version: "3.2.0",
      rails_version: "7.1.0"
    )
    @generated_app.create_app_status!
    # Use a path that definitely doesn't exist
    nonexistent_path = Rails.root.join("tmp", "definitely_does_not_exist_#{SecureRandom.hex}").to_s

    @generated_app.update!(source_path: nonexistent_path)
    @generated_app.create_github_repo!  # First transition to creating_github_repo
    @generated_app.generate!            # Then transition to generating

    service = GithubCodePushService.new(@generated_app)

    error_message = "Source directory does not exist: #{nonexistent_path}"
    expected_error_message = "File system error: #{error_message}"

    # Test the error is raised and handled
    error = assert_raises(GithubCodePushService::FileSystemError) do
      service.execute
    end

    assert_equal expected_error_message, error.message

    app_status = @generated_app.app_status

    assert_equal "failed", app_status.status,
      "Expected status to be failed, but was #{app_status.status}. " \
      "Status history: #{app_status.status_history}"
    assert_equal error_message, app_status.error_message
  end
end
