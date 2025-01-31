# frozen_string_literal: true

require "test_helper"

class LocalGitServiceTest < ActiveSupport::TestCase
  include DisableParallelization

  def setup
    @workspace_path = create_test_directory("test-app")
    @logger = mock("logger")
    @logger.stubs(:info)  # Keep this as a stub
    @logger.stubs(:error)  # Keep this as a stub for general errors
    @logger.stubs(:create_entry)
    @service = LocalGitService.new(working_directory: @workspace_path, logger: @logger)
    @git_commands = sequence("git_commands")
  end

  test "initializes git repository" do
    @service.expects(:run_command).with("git init --quiet").in_sequence(@git_commands)
    @service.expects(:run_command).with("git config user.name 'railsnew.io'").in_sequence(@git_commands)
    @service.expects(:run_command).with("git config user.email 'bot@railsnew.io'").in_sequence(@git_commands)

    @service.init_repository
  end

  test "creates initial commit" do
    message = "Initial commit"
    @service.expects(:run_command).with("git add . && git -c init.defaultBranch=main commit -m '#{message}'")

    @service.create_initial_commit(message: message)
  end

  test "ensures main branch when on different branch" do
    @service.expects(:run_command).with("git rev-parse --abbrev-ref HEAD").returns("master\n")
    @service.expects(:run_command).with("git branch -M main")

    @service.ensure_main_branch
  end

  test "does not rename branch when already on main" do
    cmd = "git rev-parse --abbrev-ref HEAD"
    @service.expects(:run_command).with(cmd).returns("main\n").once
    @service.expects(:run_command).with { |arg| arg != cmd }.never

    @service.ensure_main_branch
  end

  test "sets remote when no remote exists" do
    url = "https://github.com/user/repo.git"
    @service.expects(:run_command).with("git remote -v").returns("")
    @service.expects(:run_command).with("git remote add origin #{url}")

    @service.set_remote(url: url)
  end

  test "updates remote when different URL exists" do
    url = "https://github.com/user/repo.git"
    @service.expects(:run_command).with("git remote -v").returns("origin\thttps://github.com/user/old-repo.git (fetch)\norigin\thttps://github.com/user/old-repo.git (push)")
    @service.expects(:run_command).with("git remote set-url origin #{url}")

    @service.set_remote(url: url)
  end

  test "does not update remote when correct URL exists" do
    url = "https://github.com/user/repo.git"
    cmd = "git remote -v"
    @service.expects(:run_command).with(cmd).returns("origin\t#{url} (fetch)\norigin\t#{url} (push)").once
    @service.expects(:run_command).with { |arg| arg != cmd }.never

    @service.set_remote(url: url)
  end

  test "pushes to remote" do
    token = "fake-token"
    repo_url = "https://github.com/user/repo.git"
    repo_url_with_token = "https://#{token}@github.com/user/repo.git"

    @service.expects(:run_command).with("git remote set-url origin #{repo_url_with_token}").in_sequence(@git_commands)
    Open3.expects(:capture2).with("git -c core.askpass=false push -v -u origin main").returns([ "", mock(success?: true) ]).in_sequence(@git_commands)
    @service.expects(:run_command).with("git remote set-url origin #{repo_url}").in_sequence(@git_commands)

    @service.push_to_remote(token: token, repo_url: repo_url)
  end

  test "raises error when push fails" do
    token = "fake-token"
    repo_url = "https://github.com/user/repo.git"
    repo_url_with_token = "https://#{token}@github.com/user/repo.git"

    # First set the remote URL with token
    @service.expects(:run_command).with(
      "git remote set-url origin #{repo_url_with_token}"
    ).in_sequence(@git_commands)

    # Then try to push (which fails)
    Open3.expects(:capture2).with(
      "git -c core.askpass=false push -v -u origin main"
    ).returns([ "fatal: could not read Username", mock(success?: false) ]).in_sequence(@git_commands)

    # Reset remote URL before gathering error info
    @service.expects(:run_command).with(
      "git remote set-url origin #{repo_url}"
    ).in_sequence(@git_commands)

    # Then gather error information
    @service.expects(:run_command).with(
      "git status --porcelain"
    ).returns("M modified_file.rb\n").in_sequence(@git_commands)

    @service.expects(:run_command).with(
      "git config --list"
    ).returns("user.name=Test User\n").in_sequence(@git_commands)

    # Then log the error - note that the output is stripped in the actual implementation
    # Unstub error for this specific case
    @logger.unstub(:error)
    @logger.expects(:error).with(
      "Failed to push to GitHub",
      {
        git_status: "M modified_file.rb",
        current_branch: "main",
        git_config: "user.name=Test User",
        current_path: @workspace_path,
        push_output: "fatal: could not read Username"
      }
    )

    # Verify the error is raised with correct message
    error = assert_raises(LocalGitService::Error) do
      @service.push_to_remote(token: token, repo_url: repo_url)
    end

    assert_equal "Failed to push to GitHub", error.message
  end

  test "commits changes" do
    message = "Update files"
    @service.expects(:run_command).with("git add . && git commit -m '#{message}'")

    @service.commit_changes(message: message)
  end

  test "raises error when working directory does not exist" do
    service = LocalGitService.new(working_directory: "/nonexistent", logger: @logger)

    assert_raises(LocalGitService::Error) do
      service.init_repository
    end
  end

  test "restores original directory after operation" do
    original_dir = Dir.pwd
    @service.init_repository
    assert_equal original_dir, Dir.pwd
  end

  test "restores original directory even when operation fails" do
    original_dir = Dir.pwd
    @service.expects(:run_command).raises(StandardError)

    assert_raises(StandardError) do
      @service.init_repository
    end

    assert_equal original_dir, Dir.pwd
  end

  test "prepares git repository" do
    remote_url = "https://github.com/user/repo.git"

    @service.expects(:init_repository).in_sequence(@git_commands)
    @service.expects(:ensure_main_branch).in_sequence(@git_commands)
    @service.expects(:set_remote).with(url: remote_url).in_sequence(@git_commands)

    @service.prepare_git_repository(remote_url: remote_url)
  end

  test "raises error when preparing repository in non-existent directory" do
    service = LocalGitService.new(working_directory: "/nonexistent", logger: @logger)

    error = assert_raises(LocalGitService::Error) do
      service.prepare_git_repository(remote_url: "https://github.com/user/repo.git")
    end

    assert_match(/Working directory not found at/, error.message)
  end

  test "run_command raises error when command fails" do
    command = "git remote -v"
    failed_status = mock("failed_status")
    failed_status.expects(:success?).returns(false)

    # The git status command output for error logging
    git_status_output = "M file.txt"

    Open3.expects(:capture2).with(command).returns([ "", failed_status ])
    Open3.expects(:capture2).with("git status --porcelain").returns([ git_status_output, mock ])

    @logger.unstub(:error)
    @logger.expects(:error).with(
      "Git command failed",
      {
        command: command,
        status: failed_status,
        git_status: git_status_output,
        current_path: @workspace_path
      }
    )

    Dir.chdir(@workspace_path) do
      error = assert_raises(LocalGitService::Error) do
        @service.send(:run_command, command)
      end

      # Assert both the class and message of the error
      assert_instance_of LocalGitService::Error, error
      assert_equal "Git command failed: #{command}", error.message
    end
  end

  test "validate_command! raises error for invalid command" do
    invalid_command = "git push --force"  # Not in ALLOWED_COMMANDS or ALLOWED_COMMAND_PATTERNS

    @logger.unstub(:error)
    @logger.expects(:error).with(
      "Invalid Git command",
      { command: invalid_command }
    )

    error = assert_raises(LocalGitService::Error) do
      @service.send(:validate_command!, invalid_command)
    end

    assert_equal "Invalid Git command: #{invalid_command}", error.message
  end
end
