require "test_helper"

class GitRepoCloneTest < ActiveSupport::TestCase
  setup do
    @user = users(:jane)
    stub_github_token(@user)
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
    puts "\n=== Test Setup ==="
    File.stubs(:exist?).with(@repo_path).returns(false)
    @mock_client.stubs(:repository?).returns(true)
    puts "Stubbed basic checks"

    puts "\n=== Setting up cloned git mock ==="
    branch_mock = mock("branch")
    branch_mock.stubs(:name).returns("main")

    cloned_git = mock("cloned_git")
    cloned_git.stubs(:branch).returns(branch_mock)
    cloned_git.expects(:config).with("user.name", "Jane Smith")
    cloned_git.expects(:config).with("user.email", "jane@example.com")
    cloned_git.expects(:add).with(all: true)
    cloned_git.expects(:commit).with("Test commit")
    cloned_git.expects(:push).with("origin", "main")
    puts "Set up cloned git expectations"

    puts "\n=== Setting up Git operations ==="
    Git.expects(:clone).with(
      "https://fake-token@github.com/#{@user.github_username}/#{@repo_name}.git",
      @repo_name,
      path: File.dirname(@repo_path)
    )
    Git.expects(:open).with(@repo_path).returns(cloned_git)
    puts "Set up Git clone and open expectations"

    puts "\n=== Executing Test ==="
    @repo.commit_changes(message: "Test commit", author: @user)
    puts "Test execution completed"
  end
end
