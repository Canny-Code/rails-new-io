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
    FileUtils.mkdir_p(@source_path)
    FileUtils.touch(File.join(@source_path, "test.rb"))
    FileUtils.touch(File.join(@source_path, "Gemfile"))

    # Ensure the Git repo base path exists
    FileUtils.mkdir_p(Rails.root.join("tmp", "git_repos", @user.id.to_s))

    @generated_app = GeneratedApp.create!(
      name: @repo_name,
      user: @user,
      recipe: recipes(:blog_recipe),
      source_path: @source_path.to_s
    )

    setup_github_mocks

    # Mock File.exist? to return true for template paths
    File.stubs(:exist?).returns(true)

    # Mock apply_ingredient! to prevent actual template application
    GeneratedApp.any_instance.stubs(:apply_ingredient!).returns(true)

    # Mock git operations
    git_repo = mock("git_repo")
    git_repo.stubs(:commit_changes).returns(true)
    git_repo.stubs(:create_repository).returns(true)
    AppRepositoryService.stubs(:new).returns(git_repo)
    GeneratedApp.any_instance.stubs(:repo).returns(git_repo)
  end

  teardown do
    FileUtils.rm_rf(@source_path)
    FileUtils.rm_rf(Rails.root.join("tmp", "git_repos", @user.id.to_s))
  end

  test "generates app and pushes to GitHub" do
    # Ensure the app's Git repo path exists
    repo_path = Rails.root.join("tmp", "git_repos", @user.id.to_s, "#{@repo_name}")
    FileUtils.mkdir_p(repo_path)
    FileUtils.touch(File.join(repo_path, "test.rb"))

    expect_github_operations(create_repo: true, expect_git_operations: false)
    service = mock_command_execution(@generated_app)
    service.expects(:execute).returns(true)

    AppGenerationJob.perform_now(@generated_app.id)

    @generated_app.reload
    # Set source_path again since it's not persisted
    @generated_app.source_path = @source_path.to_s
    assert_equal "completed", @generated_app.app_status.status
    assert_equal "https://github.com/test-user/#{@repo_name}", @generated_app.github_repo_url
  end

  test "handles GitHub API errors during app generation" do
    # Mock repository existence check to return true
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
