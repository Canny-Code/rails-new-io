require "test_helper"
require "minitest/mock"

class GithubRepositoryServiceTest < ActiveSupport::TestCase
  def setup
    @user = users(:john)
    @user.stubs(:github_token).returns("fake-token")
    @service = GithubRepositoryService.new(user: @user)
    @repository_name = "test-repo"
  end

  test "creates a repository successfully" do
    response = Data.define(:html_url).new(html_url: "https://github.com/#{@user.github_username}/#{@repository_name}")

    mock_client = mock("octokit_client")
    mock_client.expects(:repository?).with("#{@user.github_username}/#{@repository_name}").returns(false)
    mock_client.expects(:create_repository).with(@repository_name, {
      private: false,
      auto_init: true,
      description: "Repository created via railsnew.io",
      default_branch: "main"
    }).returns(response)

    Octokit::Client.stubs(:new).returns(mock_client)

    result = @service.create_repository(repo_name: @repository_name)
    assert_equal response.html_url, result.html_url
  end

  test "raises error when repository already exists" do
    mock_client = mock("octokit_client")
    mock_client.expects(:repository?).with("#{@user.github_username}/#{@repository_name}").returns(true)
    Octokit::Client.stubs(:new).returns(mock_client)

    error = assert_raises(GithubRepositoryService::RepositoryExistsError) do
      @service.create_repository(repo_name: @repository_name)
    end

    assert_equal "Repository 'test-repo' already exists", error.message
  end

  test "handles rate limit exceeded" do
    mock_client = mock("octokit_client")
    mock_client.stubs(:repository?).raises(Octokit::TooManyRequests.new(response_headers: {}))
    mock_client.stubs(:rate_limit).returns(Data.define(:resets_at).new(resets_at: Time.now))
    Octokit::Client.stubs(:new).returns(mock_client)

    error = assert_raises(GithubRepositoryService::ApiError) do
      @service.create_repository(repo_name: @repository_name)
    end

    assert_match /Rate limit exceeded/, error.message
  end

  test "handles general GitHub API errors" do
    mock_client = mock("octokit_client")
    mock_client.stubs(:repository?).raises(Octokit::Error.new(response_headers: {}))
    Octokit::Client.stubs(:new).returns(mock_client)

    error = assert_raises(GithubRepositoryService::ApiError) do
      @service.create_repository(repo_name: @repository_name)
    end

    assert_match /GitHub API error/, error.message
  end

  test "commits changes successfully" do
    repo_full_name = "#{@user.github_username}/#{@repository_name}"
    tree_items = [ { path: "test.txt", content: "test" } ]

    mock_client = mock("octokit_client")
    mock_client.expects(:ref).with(repo_full_name, "heads/main").returns(
      Data.define(:object).new(object: Data.define(:sha).new(sha: "old_sha"))
    )
    mock_client.expects(:commit).with(repo_full_name, "old_sha").returns(
      Data.define(:commit).new(commit: Data.define(:tree).new(tree: Data.define(:sha).new(sha: "tree_sha")))
    )
    mock_client.expects(:create_tree).with(repo_full_name, tree_items, base_tree: "tree_sha").returns(
      Data.define(:sha).new(sha: "new_tree_sha")
    )
    mock_client.expects(:create_commit).with(
      repo_full_name,
      "test commit",
      "new_tree_sha",
      "tree_sha",
      author: {
        name: @user.github_username,
        email: "#{@user.github_username}@users.noreply.github.com"
      }
    ).returns(Data.define(:sha).new(sha: "new_sha"))
    mock_client.expects(:update_ref).with(repo_full_name, "heads/main", "new_sha")

    Octokit::Client.stubs(:new).returns(mock_client)

    @service.commit_changes(
      repo_name: @repository_name,
      message: "test commit",
      tree_items: tree_items
    )
  end
end
