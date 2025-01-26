require "test_helper"
require "minitest/mock"

class GithubRepositoryServiceTest < ActiveSupport::TestCase
  def setup
    super  # Add this line to ensure fixtures are properly loaded
    @user = users(:john)
    @user.stubs(:github_token).returns("fake-token")
    @service = GithubRepositoryService.new(user: @user)
    @repository_name = "test-repo"
    # Skip sleep in tests
    GithubRepositoryService.any_instance.stubs(:sleep)
  end

  def teardown
    super
    Mocha::Mockery.instance.teardown
    Mocha::Mockery.instance.stubba.unstub_all
  end

  test "creates a repository successfully" do
    response = Data.define(:html_url).new(html_url: "https://github.com/#{@user.github_username}/#{@repository_name}")

    mock_client = mock("octokit_client")
    mock_client.expects(:repository?).with("#{@user.github_username}/#{@repository_name}").returns(false)
    mock_client.expects(:create_repository).with(
      @repository_name,
      has_entries(
        private: false,
        auto_init: true,
        description: "Repository created via railsnew.io",
        default_branch: "main"
      )
    ).returns(response)

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
    reset_time = Time.now + 10.minutes
    repo_full_name = "#{@user.github_username}/#{@repository_name}"

    # Create a proper TooManyRequests error
    rate_limit_error = Octokit::TooManyRequests.new({
      status: 429,
      body: "API rate limit exceeded",
      response_headers: { "X-RateLimit-Reset" => reset_time.to_i.to_s }
    })

    # Expect repository? to be called up to max retries (3) times and always raise
    mock_client.expects(:repository?).with(repo_full_name)
              .times(3)
              .raises(rate_limit_error)

    # Rate limit should be checked each time
    mock_client.expects(:rate_limit).times(3)
              .returns(Data.define(:resets_at).new(resets_at: reset_time))

    # We should never get to create_repository
    mock_client.expects(:create_repository).never

    Octokit::Client.stubs(:new).returns(mock_client)

    error = assert_raises(GithubRepositoryService::ApiError) do
      @service.create_repository(repo_name: @repository_name)
    end

    assert_match /Rate limit exceeded and retry attempts exhausted/, error.message
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

  test "handles unexpected errors" do
    mock_client = mock("octokit_client")
    mock_client.stubs(:repository?).raises(StandardError.new("Something went wrong"))
    Octokit::Client.stubs(:new).returns(mock_client)

    error = assert_raises(GithubRepositoryService::Error) do
      @service.create_repository(repo_name: @repository_name)
    end

    assert_equal "Unexpected error: Something went wrong", error.message
  end

  test "commits changes successfully" do
    repo_full_name = "#{@user.github_username}/#{@repository_name}"
    tree_items = [ { path: "test.txt", content: "test" } ]

    mock_client = mock("octokit_client")
    ref_response = Data.define(:object).new(object: Data.define(:sha).new(sha: "old_sha"))

    # First ref call to get base tree SHA
    mock_client.expects(:ref).with(repo_full_name, "heads/main").returns(ref_response)

    # Create a proper commit mock with both sha and commit methods
    commit_tree = Data.define(:sha).new(sha: "tree_sha")
    commit_data = Data.define(:tree).new(tree: commit_tree)
    commit = Data.define(:commit, :sha).new(commit: commit_data, sha: "old_sha")
    mock_client.expects(:commit).with(repo_full_name, "old_sha").returns(commit)

    mock_client.expects(:create_tree).with(repo_full_name, tree_items, base_tree: "tree_sha").returns(
      Data.define(:sha).new(sha: "new_tree_sha")
    )

    # Second ref call to get latest commit SHA for parent
    mock_client.expects(:ref).with(repo_full_name, "heads/main").returns(ref_response)

    expected_author = {
      name: @user.name || @user.github_username,
      email: @user.email || "#{@user.github_username}@users.noreply.github.com"
    }

    mock_client.expects(:create_commit).with(
      repo_full_name,
      "test commit",
      "new_tree_sha",
      "old_sha",
      author: expected_author
    ).returns(Data.define(:sha).new(sha: "new_sha"))
    mock_client.expects(:update_ref).with(repo_full_name, "heads/main", "new_sha")

    Octokit::Client.stubs(:new).returns(mock_client)

    result = @service.commit_changes(
      repo_name: @repository_name,
      message: "test commit",
      tree_items: tree_items
    )

    assert_equal "new_sha", result.sha
  end
end
