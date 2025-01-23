require "test_helper"

class GithubCodePushServiceTest < ActiveSupport::TestCase
  setup do
    @user = users(:jane)
    @user.stubs(:name).returns("Jane Smith")
    @user.stubs(:email).returns("jane@example.com")
    @user.stubs(:github_token).returns("fake-token")

    @repo_name = "test-app"
    @source_path = Rails.root.join("tmp", "test_source")

    # Initialize Octokit client mock
    @mock_client = mock("octokit_client")
    Octokit::Client.stubs(:new).returns(@mock_client)

    # Mock basic GitHub API responses
    @ref_mock = mock("ref")
    @ref_mock.stubs(:object).returns(OpenStruct.new(sha: "old_sha"))

    @commit_mock = mock("commit")
    @commit_mock.stubs(:commit).returns(OpenStruct.new(tree: OpenStruct.new(sha: "tree_sha")))

    @tree_mock = mock("tree")
    @tree_mock.stubs(:sha).returns("new_tree_sha")

    @new_commit_mock = mock("new_commit")
    @new_commit_mock.stubs(:sha).returns("new_sha")

    @service = GithubCodePushService.new(
      user: @user,
      repo_name: @repo_name,
      source_path: @source_path
    )
  end

  test "push_code creates repository and pushes code" do
    @mock_client.expects(:repository?).returns(false)
    @mock_client.expects(:create_repository).with(@repo_name, private: true)
    @mock_client.expects(:ref).returns(@ref_mock)
    @mock_client.expects(:commit).returns(@commit_mock)
    @mock_client.expects(:create_tree).returns(@tree_mock)
    @mock_client.expects(:create_commit).returns(@new_commit_mock)
    @mock_client.expects(:update_ref)

    @service.push_code
  end

  test "push_code updates existing repository" do
    @mock_client.expects(:repository?).returns(true)
    @mock_client.expects(:ref).returns(@ref_mock)
    @mock_client.expects(:commit).returns(@commit_mock)
    @mock_client.expects(:create_tree).returns(@tree_mock)
    @mock_client.expects(:create_commit).returns(@new_commit_mock)
    @mock_client.expects(:update_ref)

    @service.push_code
  end

  test "handles GitHub API errors" do
    @mock_client.expects(:repository?).raises(Octokit::Error.new)

    assert_raises GithubCodePushService::Error do
      @service.push_code
    end
  end
end
