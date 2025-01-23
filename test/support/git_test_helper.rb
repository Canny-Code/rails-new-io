require "ostruct"

module GitTestHelper
  GitRef = Data.define(:object)
  GitObject = Data.define(:sha)
  GitCommit = Data.define(:commit)
  GitTree = Data.define(:sha)
  GitRepo = Data.define(:html_url)

  def setup_github_mocks
    @user.stubs(:github_token).returns("fake-token")
    @user.stubs(:github_username).returns("test-user")

    # Initialize Octokit client mock
    @mock_client = mock("octokit_client")
    Octokit::Client.stubs(:new).returns(@mock_client)

    # Mock basic GitHub API responses
    @ref_mock = mock("ref")
    @ref_mock.stubs(:object).returns(GitObject.new(sha: "old_sha"))

    @commit_mock = mock("commit")
    @commit_mock.stubs(:commit).returns(GitCommit.new(commit: GitTree.new(sha: "tree_sha")))

    @tree_mock = mock("tree")
    @tree_mock.stubs(:sha).returns("new_tree_sha")

    @new_commit_mock = mock("new_commit")
    @new_commit_mock.stubs(:sha).returns("new_sha")

    # Mock repository response
    @repo_mock = GitRepo.new(html_url: "https://github.com/test-user/#{@repo_name}")
  end

  def expect_github_operations(create_repo: false, expect_git_operations: false, raise_error: false)
    if create_repo
      @mock_client.expects(:repository?).returns(false)
      @mock_client.expects(:create_repository).with(
        @repo_name,
        private: false,
        auto_init: false,
        description: "Repository created via railsnew.io"
      ).returns(@repo_mock)
    else
      if raise_error
        @mock_client.expects(:repository?).returns(true).at_least_once
      else
        @mock_client.expects(:repository?).returns(true)
      end
    end

    if expect_git_operations
      @mock_client.expects(:ref).returns(@ref_mock)
      @mock_client.expects(:commit).returns(@commit_mock)
      @mock_client.expects(:create_tree).returns(@tree_mock)
      @mock_client.expects(:create_commit).returns(@new_commit_mock)
      @mock_client.expects(:update_ref)
    end
  end
end
