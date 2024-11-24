require "test_helper"

class GithubCodePushServiceTest < ActiveSupport::TestCase
  def setup
    @user = users(:jane)
    @user.stubs(:github_token).returns("test-github-token")
    @generated_app = GeneratedApp.create!(
      name: "test-app-#{Time.current.to_i}",
      user: @user,
      ruby_version: "3.2.2",
      rails_version: "7.1.2"
    )

    @generated_app.app_status.start_generation!

    @temp_dir = Rails.root.join("tmp", "test_#{name}_#{Time.current.to_i}")
    FileUtils.mkdir_p(@temp_dir)

    @service = GithubCodePushService.new(@generated_app, @temp_dir)
  end

  def teardown
    FileUtils.rm_rf(@temp_dir) if @temp_dir && Dir.exist?(@temp_dir)

    if @generated_app && GeneratedApp.exists?(@generated_app.id)
      @generated_app.app_status&.destroy
      @generated_app.destroy
    end
  end

  test "raises FileSystemError when IO operation fails" do
    error_message = "Permission denied"
    @service.stubs(:setup_repository).raises(GithubCodePushService::FileSystemError.new(error_message))

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
    # Stub preliminary methods
    @service.stubs(:validate_source_path)  # Skip source validation
    @service.stubs(:setup_temp_directory)  # Skip directory setup

    # Setup Git expectations
    git_mock = mock("git")
    Git.expects(:init).with(@service.send(:temp_dir)).returns(git_mock)

    # Expect Git operations in sequence
    sequence = sequence("git_operations")

    # Configure git
    git_mock.expects(:config).with("user.name", @user.name).in_sequence(sequence)
    git_mock.expects(:config).with("user.email", @user.email).in_sequence(sequence)

    # Commit files
    git_mock.expects(:add).with(all: true).in_sequence(sequence)
    git_mock.expects(:commit).with("Initial commit").in_sequence(sequence)

    # Setup and push to remote
    git_mock.expects(:add_remote).with("origin", kind_of(String)).in_sequence(sequence)
    git_mock.expects(:push).with("origin", "main").in_sequence(sequence)

    # Execute
    @service.execute

    # Assert
    @generated_app.reload
    assert @generated_app.app_status.pushing_to_github?
    assert_match %r{https://github\.com/#{@user.github_username}/#{@generated_app.name}}, @generated_app.github_repo_url
  end

  test "push_code raises GitError when git operations fail" do
    Git.stubs(:init).raises(Git::Error.new("Git error"))

    error = assert_raises(GithubCodePushService::GitError) do
      @service.execute
    end

    assert_equal "Git error: Git error", error.message
    assert @generated_app.app_status.failed?
    assert_equal "Git error", @generated_app.app_status.error_message
  end

  test "handles unexpected errors with standard error handler" do
    unexpected_error = StandardError.new("Unexpected error occurred")
    @service.stubs(:push_code).raises(unexpected_error)

    error = assert_raises(GithubCodePushService::Error) do
      @service.execute
    end

    # Verify error is wrapped properly
    assert_equal "Unexpected error occurred", error.message

    # Verify app status is updated
    @generated_app.reload
    assert @generated_app.app_status.failed?
    assert_equal "Unexpected error occurred", @generated_app.app_status.error_message
  end

  test "raises FileSystemError when source directory does not exist" do
    # Use a path that definitely doesn't exist
    nonexistent_path = Rails.root.join("tmp", "definitely_does_not_exist_#{SecureRandom.hex}")
    service = GithubCodePushService.new(@generated_app, nonexistent_path)

    error = assert_raises(GithubCodePushService::FileSystemError) do
      service.execute
    end

    # Verify the error message includes the path
    assert_equal "File system error: Source directory does not exist: #{nonexistent_path}", error.message

    # Verify app status is updated
    @generated_app.reload
    assert @generated_app.app_status.failed?
    assert_equal "Source directory does not exist: #{nonexistent_path}", @generated_app.app_status.error_message
  end
end
