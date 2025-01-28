module GitTestHelper
  GitRef = Data.define(:object)
  GitObject = Data.define(:sha)
  GitCommitTree = Data.define(:sha)
  GitCommitData = Data.define(:tree)
  GitCommit = Data.define(:commit, :sha)
  GitTree = Data.define(:sha)
  GitRepo = Data.define(:html_url)

  def setup_github_mocks(recipe = nil)
    # Initialize Octokit client mock
    mock_client = mock("octokit_client")
    Octokit::Client.stubs(:new).returns(mock_client)

    # Mock basic GitHub API responses
    first_ref_mock = mock("first_ref")
    second_ref_mock = mock("second_ref")
    object_mock = GitObject.new(sha: "old_sha")
    first_ref_mock.stubs(:object).returns(object_mock)
    second_ref_mock.stubs(:object).returns(object_mock)

    commit_mock = mock("commit")
    commit_tree = GitCommitTree.new(sha: "tree_sha")
    commit_data = GitCommitData.new(tree: commit_tree)
    commit_mock.stubs(:commit).returns(commit_data)
    commit_mock.stubs(:sha).returns("old_sha")

    tree_mock = mock("tree")
    tree_mock.stubs(:sha).returns("new_tree_sha")

    new_commit_mock = mock("new_commit")
    new_commit_mock.stubs(:sha).returns("new_sha")

    # Return a struct with all the mocks
    Data.define(:client, :first_ref, :second_ref, :commit, :tree, :new_commit).new(
      client: mock_client,
      first_ref: first_ref_mock,
      second_ref: second_ref_mock,
      commit: commit_mock,
      tree: tree_mock,
      new_commit: new_commit_mock
    )
  end

  def stub_git_syncing_for(recipe)
    # Create a unique mock for each recipe
    data_repository = mock("data_repository_#{recipe.object_id}")
    DataRepositoryService.expects(:new).with(user: recipe.created_by).returns(data_repository).at_least_once
    data_repository.expects(:write_recipe).with(recipe, repo_name: DataRepositoryService.name_for_environment).at_least_once
  end

  def expect_github_operations(create_repo: false, raise_error: false)
    repo_name = @repo_name || "test-repo"
    repo_full_name = "#{@user.github_username}/#{repo_name}"
    mocks = setup_github_mocks

    if create_repo
      mocks.client.expects(:repository?).with(repo_full_name).returns(false)
      mocks.client.expects(:create_repository).with(
        repo_name,
        private: false,
        auto_init: true,
        description: "Repository created via railsnew.io",
        default_branch: "main"
      ).returns(GitRepo.new(html_url: "https://github.com/#{@user.github_username}/#{repo_name}"))

      # First ref call to get base tree SHA
      mocks.client.expects(:ref).with(repo_full_name, "heads/main").returns(mocks.first_ref)
      mocks.client.expects(:commit).with(repo_full_name, "old_sha").returns(mocks.commit)
      mocks.client.expects(:create_tree).with(
        repo_full_name,
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
      ).returns(mocks.tree)

      # Second ref call to get latest commit SHA for parent
      mocks.client.expects(:ref).with(repo_full_name, "heads/main").returns(mocks.first_ref)

      mocks.client.expects(:create_commit).with(
        repo_full_name,
        "Initialize repository structure",
        "new_tree_sha",
        "old_sha",
        author: {
          name: @user.name,
          email: @user.email
        }
      ).returns(mocks.new_commit)
      mocks.client.expects(:update_ref).with(repo_full_name, "heads/main", "new_sha")
    end

    mocks
  end
end
