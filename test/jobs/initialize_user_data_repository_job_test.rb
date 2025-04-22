require "test_helper"

class InitializeUserDataRepositoryJobTest < ActiveSupport::TestCase
  def self.test_order
    :sorted # Make test order predictable for debugging
  end

  # Define our own simple data objects instead of using GitTestHelper
  GitObject = Data.define(:sha)
  GitCommitTree = Data.define(:sha)
  GitCommitData = Data.define(:tree)

  def setup
    super
    @user = users(:john)
    @repo_name = "rails-new-io-data-test"
  end

  test "handles user not found" do
    result = InitializeUserDataRepositoryJob.perform_now(-1)
    assert_nil result, "Job should return nil when user not found"
  end

  test "re-raises error when repository initialization fails" do
    error = StandardError.new("Repository creation failed")
    User.any_instance.stubs(:github_username).returns("test-user")
    DataRepositoryService.any_instance.stubs(:initialize_repository).raises(error)

    error_raised = assert_raises StandardError do
      InitializeUserDataRepositoryJob.perform_now(@user.id)
    end
    assert_equal "Repository creation failed", error_raised.message
  end

  test "does not create repository if it already exists" do
    User.any_instance.stubs(:github_username).returns("test-user")

    mock_client = mock
    Octokit::Client.stubs(:new).returns(mock_client)
    mock_client.expects(:repository?).with("test-user/#{DataRepositoryService.name_for_environment}").returns(true)

    # Expect the structure creation attempt
    mock_client.expects(:ref).with("test-user/#{DataRepositoryService.name_for_environment}", "heads/main").returns(mock.tap { |m| m.stubs(:object).returns(GitObject.new(sha: "old_sha")) })
    mock_client.expects(:commit).with("test-user/#{DataRepositoryService.name_for_environment}", "old_sha").returns(mock.tap { |m| m.stubs(:commit).returns(GitCommitData.new(tree: GitCommitTree.new(sha: "tree_sha"))); m.stubs(:sha).returns("old_sha") })
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
    ).returns(mock.tap { |m| m.stubs(:sha).returns("new_tree_sha") })

    mock_client.expects(:ref).with("test-user/#{DataRepositoryService.name_for_environment}", "heads/main").returns(mock.tap { |m| m.stubs(:object).returns(GitObject.new(sha: "old_sha")) })

    mock_client.expects(:create_commit).with(
      "test-user/#{DataRepositoryService.name_for_environment}",
      "Initialize repository structure",
      "new_tree_sha",
      "old_sha",
      author: {
        name: @user.name,
        email: @user.email
      }
    ).returns(mock.tap { |m| m.stubs(:sha).returns("new_sha") })
    mock_client.expects(:update_ref).with(
      "test-user/#{DataRepositoryService.name_for_environment}",
      "heads/main",
      "new_sha"
    )

    # Assert that the job completes without error
    assert_nothing_raised do
      InitializeUserDataRepositoryJob.perform_now(@user.id)
    end
  end

  test "creates data repository if it does not exist" do
    User.any_instance.stubs(:github_username).returns("test-user")

    mock_client = mock
    Octokit::Client.stubs(:new).returns(mock_client)
    mock_client.expects(:repository?).with("test-user/#{DataRepositoryService.name_for_environment}").returns(false)
    mock_client.expects(:create_repository).with(
      DataRepositoryService.name_for_environment,
      private: false,
      auto_init: true,
      description: "Repository created via railsnew.io",
      default_branch: "main"
    ).returns(mock)

    # First ref call in commit_changes (for tree SHA)
    mock_client.expects(:ref).with("test-user/#{DataRepositoryService.name_for_environment}", "heads/main").returns(mock.tap { |m| m.stubs(:object).returns(GitObject.new(sha: "old_sha")) })
    mock_client.expects(:commit).with("test-user/#{DataRepositoryService.name_for_environment}", "old_sha").returns(mock.tap { |m| m.stubs(:commit).returns(GitCommitData.new(tree: GitCommitTree.new(sha: "tree_sha"))); m.stubs(:sha).returns("old_sha") })
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
    ).returns(mock.tap { |m| m.stubs(:sha).returns("new_tree_sha") })

    # Second ref call in commit_changes (for latest commit SHA)
    mock_client.expects(:ref).with("test-user/#{DataRepositoryService.name_for_environment}", "heads/main").returns(mock.tap { |m| m.stubs(:object).returns(GitObject.new(sha: "old_sha")) })

    mock_client.expects(:create_commit).with(
      "test-user/#{DataRepositoryService.name_for_environment}",
      "Initialize repository structure",
      "new_tree_sha",
      "old_sha",
      author: {
        name: @user.name,
        email: @user.email
      }
    ).returns(mock.tap { |m| m.stubs(:sha).returns("new_sha") })
    mock_client.expects(:update_ref).with(
      "test-user/#{DataRepositoryService.name_for_environment}",
      "heads/main",
      "new_sha"
    )

    # Assert that the job completes without error
    assert_nothing_raised do
      InitializeUserDataRepositoryJob.perform_now(@user.id)
    end
  end
end
