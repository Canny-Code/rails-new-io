require "test_helper"
require_relative "../support/git_test_helper"
require_relative "../support/command_execution_test_helper"

class AppGenerationWorkflowTest < ActionDispatch::IntegrationTest
  include GitTestHelper
  include CommandExecutionTestHelper

  setup do
    @user = users(:john)
    @repo_name = "test-app"
    @source_path = Rails.root.join("tmp", "test_source")

    # Clean up any existing test directories first
    FileUtils.rm_rf(@source_path) if Dir.exist?(@source_path)

    FileUtils.mkdir_p(File.join(@source_path, @repo_name))
    FileUtils.touch(File.join(@source_path, @repo_name, "test.rb"))
    FileUtils.touch(File.join(@source_path, @repo_name, "Gemfile"))

    # Initialize Git repo in the app directory
    Dir.chdir(File.join(@source_path, @repo_name)) do
      system("git init --quiet")
      system("git config user.name 'Test User'")
      system("git config user.email 'test@example.com'")
    end

    # Ensure the Git repo base path exists
    FileUtils.mkdir_p(Rails.root.join("tmp", "git_repos", @user.id.to_s))

    @generated_app = GeneratedApp.create!(
      name: @repo_name,
      user: @user,
      recipe: recipes(:blog_recipe),
      source_path: @source_path.to_s
    )

    mocks = setup_github_mocks
    @mock_client = mocks.client

    # Mock File.exist? to return true for template paths
    File.stubs(:exist?).returns(true)

    # Mock apply_ingredient! to prevent actual template application
    GeneratedApp.any_instance.stubs(:apply_ingredient!).returns(true)
  end

  teardown do
    FileUtils.rm_rf(@source_path)
    FileUtils.rm_rf(Rails.root.join("tmp", "git_repos", @user.id.to_s))
  end

  test "generates app and pushes to GitHub" do
    repo_path = Rails.root.join("tmp", "git_repos", @user.id.to_s, "#{@repo_name}")
    FileUtils.mkdir_p(repo_path)
    FileUtils.touch(File.join(repo_path, "test.rb"))

    # Mock GitHub API operations
    repo_response = GitRepo.new(html_url: "https://github.com/#{@user.github_username}/#{@repo_name}")

    @mock_client.expects(:repository?).with("#{@user.github_username}/#{@repo_name}").returns(false)
    @mock_client.expects(:create_repository).with(
      @repo_name,
      has_entries(
        private: false,
        auto_init: false,
        description: "Repository created via railsnew.io",
        default_branch: "main"
      )
    ).returns(repo_response)

    # Mock command execution (external system call)
    service = mock_command_execution(@generated_app)
    service.expects(:execute).returns(true)

    # Mock Git system commands
    AppRepositoryService.any_instance.stubs(:system).returns(true)
    AppRepositoryService.any_instance.stubs(:`).with("git rev-parse --verify HEAD 2>/dev/null").returns("")
    AppRepositoryService.any_instance.stubs(:`).with(regexp_matches(/git add \. .* && git -c init\.defaultBranch=main commit -m/)).returns("")
    AppRepositoryService.any_instance.stubs(:`).with("git rev-parse --abbrev-ref HEAD").returns("main\n")
    AppRepositoryService.any_instance.stubs(:`).with("git remote -v").returns("")
    AppRepositoryService.any_instance.stubs(:`).with("git remote add origin #{repo_response.html_url} 2>&1").returns("")
    AppRepositoryService.any_instance.stubs(:`).with("git push -v -u origin main 2>&1").returns("")

    AppGenerationJob.perform_now(@generated_app.id)

    @generated_app.reload
    @generated_app.source_path = @source_path.to_s

    assert_equal "completed", @generated_app.app_status.status
    assert_equal "https://github.com/#{@user.github_username}/#{@repo_name}", @generated_app.github_repo_url
  end

  test "handles GitHub API errors during app generation" do
    @mock_client.expects(:repository?).returns(true)
    service = mock_command_execution(@generated_app)
    service.expects(:execute).never

    error = assert_raises(GithubRepositoryService::RepositoryExistsError) do
      AppGenerationJob.perform_now(@generated_app.id)
    end

    assert_equal "Repository 'test-app' already exists", error.message

    @generated_app.reload
    # Set source_path again since it's not persisted
    @generated_app.source_path = @source_path.to_s
    assert_equal "failed", @generated_app.app_status.status
    assert_nil @generated_app.github_repo_url
    assert_equal "Repository 'test-app' already exists", @generated_app.app_status.error_message
  end
end
