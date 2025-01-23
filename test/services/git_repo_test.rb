require "test_helper"

class GitRepoTest < ActiveSupport::TestCase
  setup do
    @user = users(:jane)
    @user.stubs(:name).returns("Jane Smith")
    @user.stubs(:email).returns("jane@example.com")
    @user.stubs(:github_token).returns("fake-token")

    @repo_name = "rails-new-io-data-test"

    # Initialize Octokit client mock
    @mock_client = mock("octokit_client")
    Octokit::Client.stubs(:new).returns(@mock_client)
    @mock_client.stubs(:repository?).returns(false)

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

  test "creates initial commit with repository structure" do
    # Expect repository creation
    @mock_client.expects(:repository?).returns(false)
    @mock_client.expects(:create_repository).with(
      @repo_name,
      private: false,
      description: "Repository created via railsnew.io",
      auto_init: true,
      default_branch: "main"
    ).returns(OpenStruct.new(html_url: "https://github.com/#{@user.github_username}/#{@repo_name}"))

    # Expect tree creation
    @mock_client.expects(:ref).returns(@ref_mock)
    @mock_client.expects(:commit).returns(@commit_mock)
    @mock_client.expects(:create_tree).returns(@tree_mock)
    @mock_client.expects(:create_commit).returns(@new_commit_mock)
    @mock_client.expects(:update_ref)

    @repo.commit_changes(
      message: "Initialize repository structure",
      author: @user
    )
  end

  test "handles GitHub API errors" do
    @mock_client.expects(:repository?).raises(Octokit::Error.new)

    assert_raises GitRepo::GitError do
      @repo.commit_changes(
        message: "Initialize repository structure",
        author: @user
      )
    end
  end

  test "skips repository creation if it already exists" do
    @mock_client.expects(:repository?).returns(true)
    @mock_client.expects(:create_repository).never

    @mock_client.expects(:ref).returns(@ref_mock)
    @mock_client.expects(:commit).returns(@commit_mock)
    @mock_client.expects(:create_tree).returns(@tree_mock)
    @mock_client.expects(:create_commit).returns(@new_commit_mock)
    @mock_client.expects(:update_ref)

    @repo.commit_changes(
      message: "Initialize repository structure",
      author: @user
    )
  end

  test "creates commit with correct author information" do
    @mock_client.stubs(:repository?).returns(true)
    @mock_client.expects(:ref).returns(@ref_mock)
    @mock_client.expects(:commit).returns(@commit_mock)
    @mock_client.expects(:create_tree).returns(@tree_mock)

    # Verify author information is passed correctly
    @mock_client.expects(:create_commit).with(
      "#{@user.github_username}/#{@repo_name}",
      "Test commit",
      "new_tree_sha",
      "old_sha",
      author: {
        name: "Jane Smith",
        email: "jane@example.com"
      }
    ).returns(@new_commit_mock)

    @mock_client.expects(:update_ref)

    @repo.commit_changes(message: "Test commit", author: @user)
  end

  test "uses github username when name is missing" do
    @user.stubs(:name).returns(nil)
    @user.stubs(:github_username).returns("janehub")

    @mock_client.stubs(:repository?).returns(true)
    @mock_client.expects(:ref).returns(@ref_mock)
    @mock_client.expects(:commit).returns(@commit_mock)
    @mock_client.expects(:create_tree).returns(@tree_mock)

    # Verify fallback to github username
    @mock_client.expects(:create_commit).with(
      "#{@user.github_username}/#{@repo_name}",
      "Test commit",
      "new_tree_sha",
      "old_sha",
      author: {
        name: "janehub",
        email: "jane@example.com"
      }
    ).returns(@new_commit_mock)

    @mock_client.expects(:update_ref)

    @repo.commit_changes(message: "Test commit", author: @user)
  end
end
