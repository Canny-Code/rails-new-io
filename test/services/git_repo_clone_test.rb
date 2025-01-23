require "test_helper"

class GitRepoCloneTest < ActiveSupport::TestCase
  setup do
    @user = users(:jane)
    @user.stubs(:name).returns("Jane Smith")
    @user.stubs(:email).returns("jane@example.com")
    @user.stubs(:github_token).returns("fake-token")

    @repo_name = "rails-new-io-data-test"

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

    @repo = GitRepo.new(user: @user, repo_name: @repo_name)
  end

  test "clones repository when remote exists" do
    @mock_client.expects(:repository?).returns(true)
    @mock_client.expects(:ref).returns(@ref_mock)
    @mock_client.expects(:commit).returns(@commit_mock)
    @mock_client.expects(:create_tree).returns(@tree_mock)
    @mock_client.expects(:create_commit).with(
      "#{@user.github_username}/#{@repo_name}",
      "Clone repository",
      "new_tree_sha",
      "old_sha",
      author: {
        name: "Jane Smith",
        email: "jane@example.com"
      }
    ).returns(@new_commit_mock)
    @mock_client.expects(:update_ref)

    @repo.clone
  end

  test "raises error when repository does not exist" do
    @mock_client.expects(:repository?).returns(false)

    assert_raises GitRepo::GitError do
      @repo.clone
    end
  end

  test "handles GitHub API errors" do
    @mock_client.expects(:repository?).raises(Octokit::Error.new)

    assert_raises GitRepo::GitError do
      @repo.clone
    end
  end
end
