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

    # Create a mock status object
    status_mock = mock("status")
    status_mock.stubs(:changed).returns({ "file1" => "modified" })
    status_mock.stubs(:added).returns({})
    status_mock.stubs(:deleted).returns({})
    @git.stubs(:status).returns(status_mock)

    # Mock branches collection
    remote_branch = mock("remote_branch")
    remote_branch.stubs(:name).returns("origin/main")
    branches_collection = mock("branches_collection")
    branches_collection.stubs(:remote).returns([ remote_branch ])
    @git.stubs(:branches).returns(branches_collection)

    # Mock the current branch
    current_branch_mock = mock("current_branch")
    current_branch_mock.stubs(:name).returns("main")
    @git.stubs(:branch).returns(current_branch_mock)

    # Track the operations performed
    operations = []
    @git.expects(:fetch).tap { operations << :fetch }
    @git.expects(:reset_hard).with("origin/main").tap { operations << :reset }
    @git.expects(:config).with("user.name", "Jane Smith").tap { operations << :config_name }
    @git.expects(:config).with("user.email", "jane@example.com").tap { operations << :config_email }
    @git.expects(:add).with(all: true).tap { operations << :add }
    @git.expects(:commit).with("Test commit").tap { operations << :commit }
    @git.expects(:push).with("origin", "main").tap { operations << :push }

    @mock_client.expects(:repository?).with("#{@user.github_username}/#{@repo_name}").returns(true)

    @repo.commit_changes(message: "Test commit", author: @user)

    # Assert all operations were performed in the correct order
    expected_operations = [ :fetch, :reset, :config_name, :config_email, :add, :commit, :push ]
    assert_equal expected_operations, operations, "Git operations were not performed in the expected order"

    # Assert repository state
    assert File.exist?(@repo_path), "Repository directory does not exist"
    assert File.exist?(File.join(@repo_path, ".git")), "Git directory does not exist"
  end

  test "creates new local repository when no repository exists" do
    git_operations = []

    # Clear any existing stubs from setup
    File.unstub(:exist?)

    # Set up file existence checks
    File.stubs(:exist?).returns(false)  # Default to false for all paths
    File.stubs(:exist?).with(@repo_path).returns(false)
    File.stubs(:exist?).with(File.join(@repo_path, ".git")).returns(false)

    # Mock git branches and status (for later use)
    remote_branch = mock("remote_branch")
    remote_branch.stubs(:name).returns("origin/main")
    branches_collection = mock("branches_collection")
    branches_collection.stubs(:remote).returns([ remote_branch ])
    @git.stubs(:branches).returns(branches_collection)

    status_mock = mock("status")
    status_mock.stubs(:changed).returns({ "file1" => "modified" })
    status_mock.stubs(:added).returns({})
    status_mock.stubs(:deleted).returns({})
    @git.stubs(:status).returns(status_mock)

    current_branch_mock = mock("current_branch")
    current_branch_mock.stubs(:name).returns("main")
    @git.stubs(:branch).returns(current_branch_mock)

    # Set up GitHub API expectations
    # We expect two checks for remote_repo_exists? - both should return false initially
    @mock_client.stubs(:repository?)
                .with("#{@user.github_username}/#{@repo_name}")
                .returns(false)
                .then.returns(false)
                .then.returns(true)  # After creation

    @mock_client.expects(:create_repository)
                .with(@repo_name, private: false, description: "Repository created via railsnew.io")
                .returns(true)

    # Track git operations
    @git.expects(:config).with("init.templateDir", "").tap { |_| git_operations << "config_template" }
    @git.expects(:config).with("init.defaultBranch", "main").tap { |_| git_operations << "config_branch" }
    @git.expects(:config).with("user.name", "Jane Smith").tap { |_| git_operations << "config_name" }
    @git.expects(:config).with("user.email", "jane@example.com").tap { |_| git_operations << "config_email" }
    @git.expects(:add).with(all: true).tap { |_| git_operations << "add" }
    @git.expects(:commit).with("Test commit").tap { |_| git_operations << "commit" }
    @git.expects(:add_remote).with(
      "origin",
      "https://fake-token@github.com/#{@user.github_username}/#{@repo_name}.git"
    ).tap { |_| git_operations << "add_remote" }
    @git.expects(:push).with("origin", "main").tap { |_| git_operations << "push" }



    @repo.commit_changes(message: "Test commit", author: @user)

    # Assert operations happened in correct order
    expected_operations = [
      "config_template",
      "config_branch",
      "config_name",
      "config_email",
      "add",
      "commit",
      "add_remote",
      "push"
    ]
    assert_equal expected_operations, git_operations, "Git operations were not performed in the expected order"
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

    # Mock git branches and status
    remote_branch = mock("remote_branch")
    remote_branch.stubs(:name).returns("origin/main")
    branches_collection = mock("branches_collection")
    branches_collection.stubs(:remote).returns([ remote_branch ])
    @git.stubs(:branches).returns(branches_collection)

    # Mock git status
    status_mock = mock("status")
    status_mock.stubs(:changed).returns({ "file1" => "modified" })
    status_mock.stubs(:added).returns({})
    status_mock.stubs(:deleted).returns({})
    @git.stubs(:status).returns(status_mock)

    # Mock current branch
    current_branch_mock = mock("current_branch")
    current_branch_mock.stubs(:name).returns("main")
    @git.stubs(:branch).returns(current_branch_mock)

    # Track operations
    operations = []
    @git.expects(:fetch).tap { operations << :fetch }
    @git.expects(:reset_hard).with("origin/main").tap { operations << :reset }
    @git.expects(:config).with("user.name", @user.github_username).tap { operations << :config_name }
    @git.expects(:config).with("user.email", "#{@user.github_username}@users.noreply.github.com").tap { operations << :config_email }
    @git.expects(:add).with(all: true).tap { operations << :add }
    @git.expects(:commit).with("Test commit").tap { operations << :commit }
    @git.expects(:push).with("origin", "main").tap { operations << :push }

    @mock_client.expects(:repository?).returns(true)

    @repo.commit_changes(message: "Test commit", author: @user)

    # Assert operations happened in correct order
    expected_operations = [ :fetch, :reset, :config_name, :config_email, :add, :commit, :push ]
    assert_equal expected_operations, operations, "Git operations were not performed in the expected order"
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

  test "initializes new git repo when .git directory doesn't exist" do
    # Stub File.exist? to return false for .git directory
    File.stubs(:exist?).returns(true) # default stub
    File.stubs(:exist?).with(File.join(@repo_path, ".git")).returns(false)

    # Set up expectations for create_local_repo
    FileUtils.expects(:mkdir_p).with(File.dirname(@repo_path))
    FileUtils.expects(:rm_rf).with(@repo_path)
    FileUtils.expects(:mkdir_p).with(@repo_path)

    # Expect Git.init to be called and return our mock git object
    Git.expects(:init).with(@repo_path).returns(@git)

    # Expect git config calls
    @git.expects(:config).with("init.templateDir", "")
    @git.expects(:config).with("init.defaultBranch", "main")

    # Call the git method
    result = @repo.send(:git)

    # Verify the result
    assert_equal @git, result
  end
end
