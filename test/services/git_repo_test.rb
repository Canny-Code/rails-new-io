require "test_helper"

class GitRepoTest < ActiveSupport::TestCase
  setup do
    @user = users(:jane)
    @user.stubs(:name).returns("Jane Smith")
    @user.stubs(:email).returns("jane@example.com")

    @repo_name = "rails-new-io-data-test"
    @repo_path = Rails.root.join("tmp", "git_repos", @user.id.to_s, @repo_name)

    # Create a mock git object
    @git = mock("git")
    @git.stubs(:config)
    @git.stubs(:add)
    @git.stubs(:commit)

    # Create a branch mock explicitly
    @branch_mock = mock("branch")
    @branch_mock.stubs(:name).returns("main")
    @git.stubs(:branch).returns(@branch_mock)

    Git.stubs(:init).returns(@git)
    Git.stubs(:open).returns(@git)
    Git.stubs(:clone)

    # Stub file operations
    File.stubs(:write).returns(true)
    File.stubs(:exist?).returns(true)
    File.stubs(:read).returns("# Repository\nCreated via railsnew.io")
    Dir.stubs(:glob).returns([])

    # Initialize Octokit client mock
    @mock_client = mock("octokit_client")
    Octokit::Client.stubs(:new).returns(@mock_client)

    # Stub all FileUtils operations globally
    FileUtils.stubs(:mkdir_p)
    FileUtils.stubs(:rm_rf)

    @repo = GitRepo.new(user: @user, repo_name: @repo_name)
  end

  teardown do
    FileUtils.rm_rf(@repo_path) if File.exist?(@repo_path)
    FileUtils.rm_rf(File.dirname(@repo_path)) if File.exist?(File.dirname(@repo_path))
  end

  test "commits changes to existing local repository" do
    File.stubs(:exist?).with(@repo_path).returns(true)
    File.stubs(:exist?).with(File.join(@repo_path, ".git")).returns(true)

    @git.expects(:fetch)
    @git.expects(:reset_hard).with("origin/main")
    @git.expects(:config).with("user.name", "Jane Smith")
    @git.expects(:config).with("user.email", "jane@example.com")
    @git.expects(:add).with(all: true)
    @git.expects(:commit).with("Test commit")
    @git.expects(:push).with("origin", "main")

    @mock_client.expects(:repository?).with("#{@user.github_username}/#{@repo_name}").returns(true)

    @repo.commit_changes(message: "Test commit", author: @user)
  end

  test "creates new local repository when no repository exists" do
    File.stubs(:exist?).with(@repo_path).returns(false)
    File.stubs(:exist?).with(File.join(@repo_path, ".git")).returns(false)

    @mock_client.expects(:repository?).with("#{@user.github_username}/#{@repo_name}").returns(false).twice
    @mock_client.expects(:create_repository).with(
      @repo_name,
      private: false,
      description: "Repository created via railsnew.io"
    ).returns(true)

    @git.expects(:config).with("init.templateDir", "")
    @git.expects(:config).with("init.defaultBranch", "main")
    @git.expects(:config).with("user.name", "Jane Smith")
    @git.expects(:config).with("user.email", "jane@example.com")
    @git.expects(:add).with(all: true)
    @git.expects(:commit).with("Test commit")
    @git.expects(:add_remote).with("origin", "https://fake-token@github.com/#{@user.github_username}/#{@repo_name}.git")
    @git.expects(:push).with("origin", "main")

    FileUtils.expects(:mkdir_p).with(File.dirname(@repo_path))
    FileUtils.stubs(:rm_rf).with(@repo_path)
    FileUtils.expects(:mkdir_p).with(@repo_path)

    @repo.commit_changes(message: "Test commit", author: @user)
  end

  test "handles GitHub API errors when checking repository existence" do
    error = Octokit::Error.new(
      method: :get,
      url: "https://api.github.com/repos/#{@user.github_username}/#{@repo_name}",
      status: 401,
      response_headers: {},
      body: { message: "Bad credentials" }
    )

    test_logger = mock("logger")
    test_logger.expects(:error).with("Failed to check GitHub repository: #{error.message}")
    Rails.stubs(:logger).returns(test_logger)

    @mock_client.expects(:repository?).raises(error)

    # Should return false and continue with local repo creation
    @repo.send(:remote_repo_exists?)
  end

  test "handles missing user name and email" do
    @user.stubs(:name).returns(nil)
    @user.stubs(:email).returns(nil)

    File.stubs(:exist?).with(@repo_path).returns(true)
    File.stubs(:exist?).with(File.join(@repo_path, ".git")).returns(true)

    @git.expects(:fetch)
    @git.expects(:reset_hard).with("origin/main")
    @git.expects(:config).with("user.name", @user.github_username)
    @git.expects(:config).with("user.email", "#{@user.github_username}@users.noreply.github.com")
    @git.expects(:add).with(all: true)
    @git.expects(:commit).with("Test commit")
    @git.expects(:push).with("origin", "main")

    @mock_client.expects(:repository?).returns(true)

    @repo.commit_changes(message: "Test commit", author: @user)
  end

  test "ensures committable state by creating README.md" do
    File.stubs(:exist?).with(@repo_path).returns(true)
    File.stubs(:exist?).with(File.join(@repo_path, ".git")).returns(true)

    File.expects(:write).with(
      File.join(@repo_path, "README.md"),
      "# Repository\nCreated via railsnew.io"
    )

    @repo.send(:ensure_committable_state)
  end

  test "creates GitHub repository with correct parameters" do
    @mock_client.expects(:create_repository).with(
      @repo_name,
      private: false,
      description: "Repository created via railsnew.io"
    )

    @repo.send(:create_github_repo)
  end
end
