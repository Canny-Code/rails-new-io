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

    # Mock the ref call to get master branch SHA
    master_ref = Data.define(:object).new(object: Data.define(:sha).new(sha: "master_sha"))
    mock_client.expects(:ref).with("#{@user.github_username}/#{@repository_name}", "heads/master").returns(master_ref)
    mock_client.expects(:create_ref).with("#{@user.github_username}/#{@repository_name}", "refs/heads/main", "master_sha")
    mock_client.expects(:edit_repository).with("#{@user.github_username}/#{@repository_name}", default_branch: "main")
    mock_client.expects(:delete_ref).with("#{@user.github_username}/#{@repository_name}", "heads/master")

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

    # Update generated_app with the test workspace path
    @generated_app.update!(workspace_path: workspace_path)

    # Initialize git repo and set up remote
    git_service = LocalGitService.new(working_directory: app_dir, logger: @service.logger)
    git_service.in_working_directory do
      Open3.capture2("git init --quiet")
      Open3.capture2("git config user.name 'Test User'")
      Open3.capture2("git config user.email 'test@example.com'")
      Open3.capture2("git add .")
      Open3.capture2("git -c init.defaultBranch=main commit -m 'Initial commit' --quiet")
      Open3.capture2("git remote add origin #{@generated_app.github_repo_url}")
    end

    # Create a LocalGitService mock that will be used by AppRepositoryService
    mock_git_service = mock("local_git_service")
    LocalGitService.expects(:new).with(
      working_directory: app_dir,
      logger: @service.logger
    ).returns(mock_git_service)

    # Set up expectations for the mock in sequence
    mock_git_service.expects(:ensure_main_branch).in_sequence(@git_commands)
    mock_git_service.expects(:push_to_remote).with(
      token: @user.github_token,
      repo_url: @generated_app.github_repo_url
    ).in_sequence(@git_commands)

    within_test_directory(app_dir) do
      Open3.capture2("git remote -v")

      # Verify initial state
      assert File.directory?(app_dir), "App directory should exist"
      assert File.directory?(File.join(app_dir, ".git")), "Git directory should exist"

      @service.push_to_remote
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

    @generated_app.update!(
      name: @repository_name,
      github_repo_url: "https://github.com/#{@user.github_username}/#{@repository_name}",
      workspace_path: workspace_path
    )

    # Initialize empty git repo
    git_service = LocalGitService.new(working_directory: app_dir, logger: @service.logger)
    git_service.in_working_directory do
      Open3.capture2("git init --quiet")
      Open3.capture2("git config user.name 'Test User'")
      Open3.capture2("git config user.email 'test@example.com'")
    end

    # Create a LocalGitService mock that will be used by AppRepositoryService
    mock_git_service = mock("local_git_service")
    LocalGitService.expects(:new).with(
      working_directory: app_dir,
      logger: @service.logger
    ).returns(mock_git_service)

    # Set up expectations for the mock in sequence
    mock_git_service.expects(:prepare_git_repository).with(
      remote_url: @generated_app.github_repo_url
    ).in_sequence(@git_commands)

    mock_git_service.expects(:create_initial_commit).with(
      message: @generated_app.to_commit_message
    ).in_sequence(@git_commands)

    within_test_directory(app_dir) do
      @service.create_initial_commit
    end
  end

  test "renames branch to main when on different branch" do
    workspace_path = create_test_directory("test-app")
    app_dir = File.join(workspace_path, @repository_name)
    FileUtils.mkdir_p(app_dir)

    @generated_app.update!(
      name: @repository_name,
      github_repo_url: "https://github.com/#{@user.github_username}/#{@repository_name}",
      workspace_path: workspace_path
    )

    # Initialize git repo with master branch
    git_service = LocalGitService.new(working_directory: app_dir, logger: @service.logger)
    git_service.in_working_directory do
      Open3.capture2("git init --quiet")
      Open3.capture2("git config user.name 'Test User'")
      Open3.capture2("git config user.email 'test@example.com'")
      Open3.capture2("git checkout -b master --quiet")  # Explicitly create master branch
      Open3.capture2("git add . 2>/dev/null")
      Open3.capture2("git commit --allow-empty -m 'Initial commit' --quiet")
      Open3.capture2("git remote add origin #{@generated_app.github_repo_url}")
    end

    # Create a LocalGitService mock that will be used by AppRepositoryService
    mock_git_service = mock("local_git_service")
    LocalGitService.expects(:new).with(
      working_directory: app_dir,
      logger: @service.logger
    ).returns(mock_git_service)

    # Set up expectations for the mock
    mock_git_service.expects(:ensure_main_branch)
    mock_git_service.expects(:push_to_remote).with(
      token: @user.github_token,
      repo_url: @generated_app.github_repo_url
    )

    within_test_directory(app_dir) do
      @service.push_to_remote
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

    # Create a LocalGitService mock that will be used by AppRepositoryService
    mock_git_service = mock("local_git_service")
    LocalGitService.expects(:new).with(
      working_directory: app_dir,
      logger: @service.logger
    ).returns(mock_git_service)

    # Set up expectations for the mock
    mock_git_service.expects(:ensure_main_branch).raises(LocalGitService::Error.new("Not a git repository"))

    error = assert_raises(LocalGitService::Error) do
      within_test_directory(app_dir) do
        @service.push_to_remote
      end
    end

    assert_match(/Not a git repository/, error.message)
  end

  test "raises error when initial commit creation fails" do
    workspace_path = create_test_directory("test-app")
    app_dir = File.join(workspace_path, @repository_name)
    FileUtils.mkdir_p(app_dir)

    @generated_app.update!(
      name: @repository_name,
      github_repo_url: "https://github.com/#{@user.github_username}/#{@repository_name}",
      workspace_path: workspace_path
    )

    # Initialize empty git repo
    git_service = LocalGitService.new(working_directory: app_dir, logger: @service.logger)
    git_service.in_working_directory do
      Open3.capture2("git init --quiet")
      Open3.capture2("git config user.name 'Test User'")
      Open3.capture2("git config user.email 'test@example.com'")
    end

    # Create a LocalGitService mock that will be used by AppRepositoryService
    mock_git_service = mock("local_git_service")
    LocalGitService.expects(:new).with(
      working_directory: app_dir,
      logger: @service.logger
    ).returns(mock_git_service)

    # Set up expectations for the mock in sequence
    mock_git_service.expects(:prepare_git_repository).with(
      remote_url: @generated_app.github_repo_url
    ).in_sequence(@git_commands)

    mock_git_service.expects(:create_initial_commit).with(
      message: @generated_app.to_commit_message
    ).raises(LocalGitService::Error.new("Git command failed: Failed to create initial commit")).in_sequence(@git_commands)

    error = assert_raises(LocalGitService::Error) do
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

    @generated_app.update!(
      name: @repository_name,
      github_repo_url: "https://github.com/#{@user.github_username}/#{@repository_name}",
      workspace_path: workspace_path
    )

    # Initialize git repo with master branch
    git_service = LocalGitService.new(working_directory: app_dir, logger: @service.logger)
    git_service.in_working_directory do
      Open3.capture2("git init --quiet")
      Open3.capture2("git config user.name 'Test User'")
      Open3.capture2("git config user.email 'test@example.com'")
      Open3.capture2("git checkout -b master --quiet")  # Explicitly create master branch
      Open3.capture2("git add . 2>/dev/null")
      Open3.capture2("git commit --allow-empty -m 'Initial commit' --quiet")
      Open3.capture2("git remote add origin #{@generated_app.github_repo_url}")
    end

    # Create a LocalGitService mock that will be used by AppRepositoryService
    mock_git_service = mock("local_git_service")
    LocalGitService.expects(:new).with(
      working_directory: app_dir,
      logger: @service.logger
    ).returns(mock_git_service)

    # Set up expectations for the mock
    mock_git_service.expects(:ensure_main_branch).raises(
      LocalGitService::Error.new("Git command failed: Failed to rename branch to main")
    )

    error = assert_raises(LocalGitService::Error) do
      within_test_directory(app_dir) do
        @service.push_to_remote
      end
    end

    assert_match(/Failed to rename branch to main/, error.message)
  end
end
