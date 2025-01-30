require "test_helper"

class AppRepositoryServiceTest < ActiveSupport::TestCase
  include DisableParallelization

  def setup
    @user = users(:john)
    @user.stubs(:github_token).returns("fake-token")
    @repository_name = "test-repo"
    @generated_app = generated_apps(:pending_app)
    @generated_app.update!(
      name: @repository_name,
      github_repo_url: "https://github.com/#{@user.github_username}/#{@repository_name}"
    )
    mock_logger = mock("logger")
    mock_logger.stubs(:info).returns(true)
    mock_logger.stubs(:error).returns(true)
    mock_logger.stubs(:create_entry).returns(true)
    @generated_app.stubs(:logger).returns(mock_logger)
    @service = AppRepositoryService.new(@generated_app, mock_logger)
    @git_commands = sequence("git_commands")
  end

  test "initializes repository and updates generated app" do
    response = Data.define(:html_url).new(html_url: "https://github.com/#{@user.github_username}/#{@repository_name}")

    mock_client = mock("octokit_client")
    mock_client.expects(:repository?).with("#{@user.github_username}/#{@repository_name}").returns(false)
    mock_client.expects(:create_repository).with(
      @repository_name,
      private: false,
      auto_init: false,
      description: "Repository created via railsnew.io",
      default_branch: "main"
    ).returns(response)

    Octokit::Client.stubs(:new).returns(mock_client)

    @generated_app.name = @repository_name
    result = @service.create_github_repository
    assert_equal response.html_url, result.html_url

    # Verify GeneratedApp was updated
    @generated_app.reload
    assert_equal @repository_name, @generated_app.name
    assert_equal response.html_url, @generated_app.github_repo_url
  end

  test "pushes app files to repository with existing commits" do
    workspace_path = create_test_directory("test-app")
    app_dir = File.join(workspace_path, @repository_name)
    FileUtils.mkdir_p(app_dir)
    File.write(File.join(app_dir, "test.rb"), "puts 'test'")
    init_git_repo(app_dir)

    @generated_app.update!(
      name: @repository_name,
      github_repo_url: "https://github.com/#{@user.github_username}/#{@repository_name}",
      workspace_path: workspace_path
    )

    # Mock directory checks - be explicit about each path
    File.stubs(:directory?).returns(false)  # Default to false for safety
    File.stubs(:directory?).with(workspace_path).returns(true)
    File.stubs(:directory?).with(app_dir).returns(true)
    File.stubs(:directory?).with(".git").returns(true)  # This is checked relative to current directory
    File.stubs(:directory?).with(File.join(app_dir, ".git")).returns(true)  # Also allow absolute path check

    # Mock git commands that need output
    @service.stubs(:run_command).with("git rev-parse --verify HEAD 2>/dev/null").returns("existing-sha")  # Has commits
    @service.stubs(:run_command).with("git rev-parse --abbrev-ref HEAD").returns("main\n")
    @service.stubs(:run_command).with("git remote -v").returns("origin\thttps://github.com/johndoe/test-repo (fetch)\norigin\thttps://github.com/johndoe/test-repo (push)\n")
    @service.stubs(:run_command).with("git status --porcelain").returns("")
    @service.stubs(:run_command).with("git config --list").returns("")

    # Mock system calls - all should succeed
    @service.stubs(:system).returns(true)  # Default success for safety

    # Expect specific system calls in sequence
    repo_url_with_token = "https://#{@user.github_token}@github.com/#{@user.github_username}/#{@repository_name}"

    # First setup_remote is called by prepare_git_repository
    # Since remote exists with correct URL, no need to add/update it

    # Then push_to_remote does its work
    @service.expects(:system).with("git remote set-url origin #{repo_url_with_token}").in_sequence(@git_commands).returns(true)
    @service.expects(:system).with("git -c core.askpass=false push -v -u origin main").in_sequence(@git_commands).returns(true)
    @service.expects(:system).with("git remote set-url origin #{@generated_app.github_repo_url}").in_sequence(@git_commands).returns(true)

    # Save the original directory
    original_dir = Dir.pwd

    begin
      within_test_directory(app_dir) do
        puts "DEBUG: Current directory: #{Dir.pwd}"
        puts "DEBUG: Git directory exists: #{File.directory?('.git')}"
        puts "DEBUG: App directory exists: #{File.directory?(app_dir)}"
        puts "DEBUG: Git remotes:"
        puts @service.send(:run_command, "git remote -v")
        result = @service.push_to_remote
        assert_nil result
      end
    ensure
      # Always restore the original directory
      Dir.chdir(original_dir) if Dir.exist?(original_dir)
    end
  end

  test "skips pushing files for non-existent workspace path" do
    # No client should be created since we're skipping
    Octokit::Client.expects(:new).never

    workspace_path = "/nonexistent/path"
    app_dir = File.join(workspace_path, @repository_name)
    @generated_app.update!(workspace_path: workspace_path)

    # Mock directory checks - be explicit about each path
    File.stubs(:directory?).returns(false)  # Default to false for safety
    File.stubs(:directory?).with(workspace_path).returns(false)
    File.stubs(:directory?).with(app_dir).returns(false)

    # Should raise error about missing workspace path
    error = assert_raises(RuntimeError) do
      @service.push_to_remote
    end

    assert_match(/Rails app directory not found at/, error.message)
  end

  test "raises error when app directory is missing" do
    workspace_path = create_test_directory("test-app")
    FileUtils.mkdir_p(workspace_path)

    @generated_app.update!(workspace_path: workspace_path)

    # Mock directory checks
    File.stubs(:directory?).returns(true)  # Default for safety
    File.stubs(:directory?).with(workspace_path).returns(true)
    app_dir = File.join(workspace_path, @repository_name)
    File.stubs(:directory?).with(app_dir).returns(false)  # This triggers the error

    error = assert_raises(RuntimeError) do
      @service.push_to_remote
    end

    assert_match(/Rails app directory not found at/, error.message)
  end

  test "creates initial commit when repository has no commits" do
    workspace_path = create_test_directory("test-app")
    app_dir = File.join(workspace_path, @repository_name)
    FileUtils.mkdir_p(app_dir)
    init_git_repo(app_dir)

    @generated_app.update!(
      name: @repository_name,
      github_repo_url: "https://github.com/#{@user.github_username}/#{@repository_name}",
      workspace_path: workspace_path
    )

    # Mock directory checks
    File.stubs(:directory?).returns(true)  # Default for safety
    File.stubs(:directory?).with(workspace_path).returns(true)
    File.stubs(:directory?).with(app_dir).returns(true)
    File.stubs(:directory?).with(".git").returns(true)

    # Mock git commands that need output
    @service.stubs(:run_command).with("git rev-parse --verify HEAD 2>/dev/null").returns("")  # No commits yet
    @service.stubs(:run_command).with("git rev-parse --abbrev-ref HEAD").returns("main\n")
    @service.stubs(:run_command).with("git remote -v").returns("")
    @service.stubs(:run_command).with("git status --porcelain").returns("")
    @service.stubs(:run_command).with("git config --list").returns("")

    # Mock system calls - all should succeed
    @service.stubs(:system).returns(true)  # Default success for safety

    # Expect specific system calls in sequence
    commit_command = "git add . && git -c init.defaultBranch=main commit -m '#{@service.send(:initial_commit_message)}'"
    @service.expects(:system).with(commit_command).in_sequence(@git_commands).returns(true)
    @service.expects(:system).with("git remote add origin #{@generated_app.github_repo_url}").in_sequence(@git_commands).returns(true)
    @service.expects(:system).with("git remote set-url origin https://#{@user.github_token}@github.com/#{@user.github_username}/#{@repository_name}").in_sequence(@git_commands).returns(true)
    @service.expects(:system).with("git -c core.askpass=false push -v -u origin main").in_sequence(@git_commands).returns(true)
    @service.expects(:system).with("git remote set-url origin #{@generated_app.github_repo_url}").in_sequence(@git_commands).returns(true)

    within_test_directory(app_dir) do
      @service.create_initial_commit
      result = @service.push_to_remote
      assert_nil result
    end
  end

  test "renames branch to main when on different branch" do
    workspace_path = create_test_directory("test-app")
    app_dir = File.join(workspace_path, @repository_name)
    FileUtils.mkdir_p(app_dir)
    init_git_repo(app_dir)

    @generated_app.update!(
      name: @repository_name,
      github_repo_url: "https://github.com/#{@user.github_username}/#{@repository_name}",
      workspace_path: workspace_path
    )

    # Mock directory checks
    File.stubs(:directory?).returns(true)  # Default for safety
    File.stubs(:directory?).with(workspace_path).returns(true)
    File.stubs(:directory?).with(app_dir).returns(true)
    File.stubs(:directory?).with(".git").returns(true)

    # Mock git commands that need output
    @service.stubs(:run_command).with("git rev-parse --verify HEAD 2>/dev/null").returns("existing-sha")  # Has commits
    @service.stubs(:run_command).with("git rev-parse --abbrev-ref HEAD").returns("master\n")  # On master branch
    @service.stubs(:run_command).with("git remote -v").returns("")
    @service.stubs(:run_command).with("git status --porcelain").returns("")
    @service.stubs(:run_command).with("git config --list").returns("")

    # Mock system calls - all should succeed
    @service.stubs(:system).returns(true)  # Default success for safety

    # Expect specific system calls in sequence
    @service.expects(:system).with("git branch -M main").in_sequence(@git_commands).returns(true)  # Rename branch
    @service.expects(:system).with("git remote add origin #{@generated_app.github_repo_url}").in_sequence(@git_commands).returns(true)
    @service.expects(:system).with("git remote set-url origin https://#{@user.github_token}@github.com/#{@user.github_username}/#{@repository_name}").in_sequence(@git_commands).returns(true)
    @service.expects(:system).with("git -c core.askpass=false push -v -u origin main").in_sequence(@git_commands).returns(true)
    @service.expects(:system).with("git remote set-url origin #{@generated_app.github_repo_url}").in_sequence(@git_commands).returns(true)

    within_test_directory(app_dir) do
      result = @service.push_to_remote
      assert_nil result
    end
  end

  test "raises error when directory is not a git repository" do
    workspace_path = create_test_directory("test-app")
    app_dir = File.join(workspace_path, @repository_name)
    FileUtils.mkdir_p(app_dir)
    File.write(File.join(app_dir, "test.rb"), "puts 'test'")  # Add a file to make it a valid directory

    @generated_app.update!(
      name: @repository_name,
      github_repo_url: "https://github.com/#{@user.github_username}/#{@repository_name}",
      workspace_path: workspace_path
    )

    # Mock directory checks
    File.stubs(:directory?).returns(true)  # Default for safety
    File.stubs(:directory?).with(workspace_path).returns(true)
    File.stubs(:directory?).with(app_dir).returns(true)
    File.stubs(:directory?).with(".git").returns(false)  # This triggers the error

    error = assert_raises(RuntimeError) do
      within_test_directory(app_dir) do
        @service.push_to_remote
      end
    end

    assert_match(/Not a git repository at/, error.message)
  end

  test "raises error when initial commit creation fails" do
    workspace_path = create_test_directory("test-app")
    app_dir = File.join(workspace_path, @repository_name)
    FileUtils.mkdir_p(app_dir)
    init_git_repo(app_dir)

    @generated_app.update!(
      name: @repository_name,
      github_repo_url: "https://github.com/#{@user.github_username}/#{@repository_name}",
      workspace_path: workspace_path
    )

    # Mock directory checks
    File.stubs(:directory?).returns(true)  # Default for safety
    File.stubs(:directory?).with(workspace_path).returns(true)
    File.stubs(:directory?).with(app_dir).returns(true)
    File.stubs(:directory?).with(".git").returns(true)

    # Mock git commands
    @service.stubs(:run_command).with("git rev-parse --verify HEAD 2>/dev/null").returns("")  # No commits yet
    @service.stubs(:run_command).with("git rev-parse --abbrev-ref HEAD").returns("main\n")
    @service.stubs(:run_command).with("git remote -v").returns("")
    @service.stubs(:run_command).with("git status --porcelain").returns("?? test.rb")  # Untracked file
    @service.stubs(:run_command).with("git config --list").returns("")

    # Mock system calls - make the initial commit fail
    @service.stubs(:system).returns(true)  # Default success for safety
    commit_command = "git add . && git -c init.defaultBranch=main commit -m '#{@service.send(:initial_commit_message)}'"
    @service.expects(:system).with(commit_command).in_sequence(@git_commands).returns(false)  # This is the failure we're testing

    error = assert_raises(RuntimeError) do
      within_test_directory(app_dir) do
        @service.create_initial_commit
      end
    end

    assert_match(/Failed to create initial commit/, error.message)
  end

  test "raises error when branch rename fails" do
    workspace_path = create_test_directory("test-app")
    app_dir = File.join(workspace_path, @repository_name)
    FileUtils.mkdir_p(app_dir)
    init_git_repo(app_dir)

    @generated_app.update!(
      name: @repository_name,
      github_repo_url: "https://github.com/#{@user.github_username}/#{@repository_name}",
      workspace_path: workspace_path
    )

    # Mock directory checks
    File.stubs(:directory?).returns(true)  # Default for safety
    File.stubs(:directory?).with(workspace_path).returns(true)
    File.stubs(:directory?).with(app_dir).returns(true)
    File.stubs(:directory?).with(".git").returns(true)

    # Mock git commands that need output
    @service.stubs(:run_command).with("git rev-parse --verify HEAD 2>/dev/null").returns("existing-sha")  # Has commits
    @service.stubs(:run_command).with("git rev-parse --abbrev-ref HEAD").returns("master\n")  # On master branch
    @service.stubs(:run_command).with("git remote -v").returns("")
    @service.stubs(:run_command).with("git status --porcelain").returns("")
    @service.stubs(:run_command).with("git config --list").returns("")

    # Mock system calls - make the branch rename fail
    @service.stubs(:system).returns(true)  # Default success for safety
    @service.expects(:system).with("git branch -M main").in_sequence(@git_commands).returns(false)  # This is the failure we're testing

    error = assert_raises(RuntimeError) do
      within_test_directory(app_dir) do
        @service.push_to_remote
      end
    end

    assert_match(/Failed to rename branch to main/, error.message)
  end
end
