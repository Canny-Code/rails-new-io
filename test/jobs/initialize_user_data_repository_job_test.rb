require "test_helper"
require_relative "../support/git_test_helper"

class InitializeUserDataRepositoryJobTest < ActiveSupport::TestCase
  include GitTestHelper

  def setup
    super
    @user = users(:john)
    @repo_name = "rails-new-io-data-test"
  end

  def teardown
    super
    # Clean up all mocks and stubs
    Mocha::Mockery.instance.teardown
    Mocha::Mockery.instance.stubba.unstub_all
  end

  def mock_logger_for_job
    logger = mock("logger")
    logger.stubs(:info?) # Allow info? calls
    logger.stubs(:error?) # Allow error? calls
    logger.stubs(:debug?) # Allow debug? calls
    logger.stubs(:warn?) # Allow warn? calls
    logger.stubs(:fatal?) # Allow fatal? calls
    logger
  end

  def with_mocked_logger
    logger = mock_logger_for_job
    original_logger = Rails.logger
    begin
      Rails.stubs(:logger).returns(logger)
      yield logger
    ensure
      Rails.unstub(:logger)
      Rails.logger = original_logger
    end
  end

  test "handles user not found" do
    with_mocked_logger do |logger|
      logger.expects(:info).with("Starting InitializeUserDataRepositoryJob for user_id: -1")
      logger.expects(:error).with("User not found with id: -1")

      result = InitializeUserDataRepositoryJob.perform_now(-1)
      assert_nil result, "Job should return nil when user not found"
    end
  end

  test "logs and re-raises error when repository initialization fails" do
    error = StandardError.new("Repository creation failed")
    error.set_backtrace([ "line 1", "line 2" ])

    # Set up stubs before mocking the logger
    User.any_instance.stubs(:github_username).returns("test-user")
    DataRepositoryService.any_instance.stubs(:initialize_repository).raises(error)

    with_mocked_logger do |logger|
      logger.expects(:info).with("Starting InitializeUserDataRepositoryJob for user_id: #{@user.id}")
      logger.expects(:info).with("Creating data repository for user: test-user")
      logger.expects(:error).with("Failed to initialize user data repository: Repository creation failed").once
      logger.expects(:error).with("line 1\nline 2").once

      error_raised = assert_raises StandardError do
        InitializeUserDataRepositoryJob.perform_now(@user.id)
      end
      assert_equal "Repository creation failed", error_raised.message
    end
  end

  test "does not create repository if it already exists" do
    # Set up stubs before mocking the logger
    User.any_instance.stubs(:github_username).returns("test-user")

    # Mock the repository exists check
    mock_client = mock("octokit_client")
    Octokit::Client.stubs(:new).returns(mock_client)
    mock_client.expects(:repository?).with("test-user/#{DataRepositoryService.name_for_environment}").returns(true)

    # Mock the create_initial_structure call
    mock_client.expects(:ref).with("test-user/#{DataRepositoryService.name_for_environment}", "heads/main").returns(mock("ref").tap { |m| m.stubs(:object).returns(GitObject.new(sha: "old_sha")) })
    mock_client.expects(:commit).with("test-user/#{DataRepositoryService.name_for_environment}", "old_sha").returns(mock("commit").tap { |m| m.stubs(:commit).returns(GitCommitData.new(tree: GitCommitTree.new(sha: "tree_sha"))); m.stubs(:sha).returns("old_sha") })
    mock_client.expects(:create_tree).with(
      "test-user/#{DataRepositoryService.name_for_environment}",
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
    ).returns(mock("tree").tap { |m| m.stubs(:sha).returns("new_tree_sha") })

    # Mock getting the latest commit SHA
    mock_client.expects(:ref).with("test-user/#{DataRepositoryService.name_for_environment}", "heads/main").returns(mock("ref").tap { |m| m.stubs(:object).returns(GitObject.new(sha: "old_sha")) })

    mock_client.expects(:create_commit).with(
      "test-user/#{DataRepositoryService.name_for_environment}",
      "Initialize repository structure",
      "new_tree_sha",
      "old_sha",
      author: {
        name: @user.name,
        email: @user.email
      }
    ).returns(mock("new_commit").tap { |m| m.stubs(:sha).returns("new_sha") })
    mock_client.expects(:update_ref).with(
      "test-user/#{DataRepositoryService.name_for_environment}",
      "heads/main",
      "new_sha"
    )

    with_mocked_logger do |logger|
      logger.expects(:info).with("Starting InitializeUserDataRepositoryJob for user_id: #{@user.id}")
      logger.expects(:info).with("Creating data repository for user: test-user")
      logger.expects(:error).with("Repository '#{DataRepositoryService.name_for_environment}' already exists")
      logger.expects(:info).with("Data repository creation completed")

      result = InitializeUserDataRepositoryJob.perform_now(@user.id)
      assert result.is_a?(GitRepo), "Job should return a GitRepo object"
      assert_equal "https://github.com/test-user/#{DataRepositoryService.name_for_environment}", result.html_url
    end
  end

  test "creates data repository if it does not exist" do
    # Set up stubs before mocking the logger
    User.any_instance.stubs(:github_username).returns("test-user")

    # Mock the repository exists check
    mock_client = mock("octokit_client")
    Octokit::Client.stubs(:new).returns(mock_client)
    mock_client.expects(:repository?).with("test-user/#{DataRepositoryService.name_for_environment}").returns(false)
    mock_client.expects(:create_repository).with(
      DataRepositoryService.name_for_environment,
      private: false,
      auto_init: true,
      description: "Repository created via railsnew.io",
      default_branch: "main"
    ).returns(GitRepo.new(html_url: "https://github.com/test-user/#{DataRepositoryService.name_for_environment}"))

    # Mock the create_initial_structure call
    mock_client.expects(:ref).with("test-user/#{DataRepositoryService.name_for_environment}", "heads/main").returns(mock("ref").tap { |m| m.stubs(:object).returns(GitObject.new(sha: "old_sha")) })
    mock_client.expects(:commit).with("test-user/#{DataRepositoryService.name_for_environment}", "old_sha").returns(mock("commit").tap { |m| m.stubs(:commit).returns(GitCommitData.new(tree: GitCommitTree.new(sha: "tree_sha"))); m.stubs(:sha).returns("old_sha") })
    mock_client.expects(:create_tree).with(
      "test-user/#{DataRepositoryService.name_for_environment}",
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
    ).returns(mock("tree").tap { |m| m.stubs(:sha).returns("new_tree_sha") })

    # Mock getting the latest commit SHA
    mock_client.expects(:ref).with("test-user/#{DataRepositoryService.name_for_environment}", "heads/main").returns(mock("ref").tap { |m| m.stubs(:object).returns(GitObject.new(sha: "old_sha")) })

    mock_client.expects(:create_commit).with(
      "test-user/#{DataRepositoryService.name_for_environment}",
      "Initialize repository structure",
      "new_tree_sha",
      "old_sha",
      author: {
        name: @user.name,
        email: @user.email
      }
    ).returns(mock("new_commit").tap { |m| m.stubs(:sha).returns("new_sha") })
    mock_client.expects(:update_ref).with(
      "test-user/#{DataRepositoryService.name_for_environment}",
      "heads/main",
      "new_sha"
    )

    with_mocked_logger do |logger|
      logger.expects(:info).with("Starting InitializeUserDataRepositoryJob for user_id: #{@user.id}")
      logger.expects(:info).with("Creating data repository for user: test-user")
      logger.expects(:info).with("Data repository creation completed")

      result = InitializeUserDataRepositoryJob.perform_now(@user.id)
      assert result.is_a?(GitRepo), "Job should return a GitRepo object"
      assert_equal "https://github.com/test-user/#{DataRepositoryService.name_for_environment}", result.html_url
    end
  end
end
