require "test_helper"

class AppRepositoryServiceTest < ActiveSupport::TestCase
  include DisableParallelization

  def setup
    @user = users(:john)
    @user.stubs(:github_token).returns("fake-token")
    @generated_app = generated_apps(:pending_app)
    @service = AppRepositoryService.new(@generated_app)
    @repository_name = "test-repo"
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
    result = @service.initialize_repository
    assert_equal response.html_url, result.html_url

    # Verify GeneratedApp was updated
    @generated_app.reload
    assert_equal @repository_name, @generated_app.github_repo_name
    assert_equal response.html_url, @generated_app.github_repo_url
  end

  test "pushes app files to repository with existing commits" do
    source_path = create_test_directory("test-app")
    app_dir = File.join(source_path, @generated_app.name)
    FileUtils.mkdir_p(app_dir)
    File.write(File.join(app_dir, "test.rb"), "puts 'test'")
    init_git_repo(app_dir)

    @generated_app.update!(
      github_repo_name: @repository_name,
      github_repo_url: "https://github.com/#{@user.github_username}/#{@repository_name}"
    )

    # Mock git commands for existing repository
    @service.stubs(:`).with("git rev-parse --verify HEAD 2>/dev/null").returns("existing-sha")  # Has commits
    @service.stubs(:`).with("git rev-parse --abbrev-ref HEAD").returns("main\n")
    @service.stubs(:`).with("git remote -v").returns("")
    @service.stubs(:`).with("git status --porcelain 2>&1").returns("")
    @service.stubs(:`).with("git config --list 2>&1").returns("")
    @service.stubs(:`).with("git push -v -u origin main 2>&1").returns("")
    @service.stubs(:`).with("git remote add origin #{@generated_app.github_repo_url} 2>&1").returns("")

    # Mock $? for command success
    status_mock = mock
    status_mock.stubs(:success?).returns(true)
    @service.stubs(:$?).returns(status_mock)

    # Mock system calls
    @service.stubs(:system).with("git remote add origin #{@generated_app.github_repo_url}").returns(true)
    @service.stubs(:system).with("git remote set-url origin #{@generated_app.github_repo_url}").returns(true)
    @service.stubs(:system).with("git remote set-url origin https://#{@user.github_token}@github.com/#{@user.github_username}/#{@repository_name}").returns(true)

    result = @service.push_app_files(source_path: source_path)
    assert_nil result
  end

  test "skips pushing files for non-existent source path" do
    # No client should be created since we're skipping
    Octokit::Client.expects(:new).never

    result = @service.push_app_files(source_path: "/nonexistent/path")
    assert_nil result
  end

  test "raises error when app directory is missing" do
    source_path = create_test_directory("test-app")
    FileUtils.mkdir_p(source_path)

    error = assert_raises(RuntimeError) do
      @service.push_app_files(source_path: source_path)
    end

    assert_match(/Rails app directory not found at/, error.message)
  end

  test "creates initial commit when repository has no commits" do
    source_path = create_test_directory("test-app")
    app_dir = File.join(source_path, @generated_app.name)
    FileUtils.mkdir_p(app_dir)
    init_git_repo(app_dir)

    @generated_app.update!(
      github_repo_name: @repository_name,
      github_repo_url: "https://github.com/#{@user.github_username}/#{@repository_name}"
    )

    # Mock empty HEAD (no commits)
    @service.stubs(:`).with("git rev-parse --verify HEAD 2>/dev/null").returns("")
    @service.stubs(:`).with("git add . 2>&1 && git -c init.defaultBranch=main commit -m \"#{@service.send(:initial_commit_message)}\" 2>&1").returns("")
    @service.stubs(:`).with("git rev-parse --abbrev-ref HEAD").returns("main\n")
    @service.stubs(:`).with("git remote -v").returns("")
    @service.stubs(:`).with("git status --porcelain 2>&1").returns("")
    @service.stubs(:`).with("git push -v -u origin main 2>&1").returns("")
    @service.stubs(:`).with("git remote add origin #{@generated_app.github_repo_url} 2>&1").returns("")
    @service.stubs(:`).with("git config --list 2>&1").returns("")

    status_mock = mock
    status_mock.stubs(:success?).returns(true)
    @service.stubs(:$?).returns(status_mock)

    # Mock system calls
    @service.stubs(:system).with("git remote set-url origin #{@generated_app.github_repo_url}").returns(true)
    @service.stubs(:system).with("git remote set-url origin https://#{@user.github_token}@github.com/#{@user.github_username}/#{@repository_name}").returns(true)

    result = @service.push_app_files(source_path: source_path)
    assert_nil result
  end

  test "renames branch to main when on different branch" do
    source_path = create_test_directory("test-app")
    app_dir = File.join(source_path, @generated_app.name)
    FileUtils.mkdir_p(app_dir)
    init_git_repo(app_dir)

    @generated_app.update!(
      github_repo_name: @repository_name,
      github_repo_url: "https://github.com/#{@user.github_username}/#{@repository_name}"
    )

    # Mock branch name as 'master'
    @service.stubs(:`).with("git rev-parse --verify HEAD 2>/dev/null").returns("existing-sha")
    @service.stubs(:`).with("git rev-parse --abbrev-ref HEAD").returns("master\n")
    @service.stubs(:`).with("git branch -M main 2>&1").returns("")
    @service.stubs(:`).with("git remote -v").returns("")
    @service.stubs(:`).with("git status --porcelain 2>&1").returns("")
    @service.stubs(:`).with("git push -v -u origin main 2>&1").returns("")
    @service.stubs(:`).with("git remote add origin #{@generated_app.github_repo_url} 2>&1").returns("")
    @service.stubs(:`).with("git config --list 2>&1").returns("")

    status_mock = mock
    status_mock.stubs(:success?).returns(true)
    @service.stubs(:$?).returns(status_mock)

    # Mock system calls with specific commands
    @service.stubs(:system).with("git remote set-url origin #{@generated_app.github_repo_url}").returns(true)
    @service.stubs(:system).with("git remote set-url origin https://#{@user.github_token}@github.com/#{@user.github_username}/#{@repository_name}").returns(true)

    result = @service.push_app_files(source_path: source_path)
    assert_nil result
  end
end
