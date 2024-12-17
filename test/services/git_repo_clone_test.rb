require "test_helper"

class GitRepoCloneTest < ActiveSupport::TestCase
  setup do
    @user = users(:jane)
    @user.stubs(:name).returns("Jane Smith")
    @user.stubs(:email).returns("jane@example.com")

    @repo_name = "rails-new-io-data-test"
    @repo_path = Rails.root.join("tmp", "git_repos", @user.id.to_s, @repo_name)

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

  test "clones repository when remote exists but no local copy" do
    File.stubs(:exist?).with(@repo_path).returns(false)
    @mock_client.stubs(:repository?).returns(true)

    # Mock git status
    status_mock = mock("status")
    status_mock.stubs(:changed).returns({ "file1" => "modified" })
    status_mock.stubs(:added).returns({})
    status_mock.stubs(:deleted).returns({})

    # Mock git branches
    remote_branch = mock("remote_branch")
    remote_branch.stubs(:name).returns("origin/main")
    branches_collection = mock("branches_collection")
    branches_collection.stubs(:remote).returns([ remote_branch ])

    # Mock current branch
    current_branch_mock = mock("current_branch")
    current_branch_mock.stubs(:name).returns("main")

    # Set up cloned git mock with all required stubs
    cloned_git = mock("cloned_git")
    cloned_git.stubs(:branch).returns(current_branch_mock)
    cloned_git.stubs(:branches).returns(branches_collection)
    cloned_git.stubs(:status).returns(status_mock)

    # Track operations
    operations = []
    cloned_git.expects(:config).with("user.name", "Jane Smith").tap { operations << :config_name }
    cloned_git.expects(:config).with("user.email", "jane@example.com").tap { operations << :config_email }
    cloned_git.expects(:add).with(all: true).tap { operations << :add }
    cloned_git.expects(:commit).with("Test commit").tap { operations << :commit }
    cloned_git.expects(:push).with("origin", "main").tap { operations << :push }

    Git.expects(:clone).with(
      "https://fake-token@github.com/#{@user.github_username}/#{@repo_name}.git",
      @repo_name,
      path: File.dirname(@repo_path)
    )
    Git.expects(:open).with(@repo_path).returns(cloned_git)

    @repo.commit_changes(message: "Test commit", author: @user)

    # Assert operations happened in correct order
    expected_operations = [ :config_name, :config_email, :add, :commit, :push ]
    assert_equal expected_operations, operations, "Git operations were not performed in the expected order"
  end
end
