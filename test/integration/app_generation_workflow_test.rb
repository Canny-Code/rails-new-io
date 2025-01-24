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
  end

  teardown do
    FileUtils.rm_rf(@source_path)
    FileUtils.rm_rf(Rails.root.join("tmp", "git_repos", @user.id.to_s))
  end

  test "generates app and pushes to GitHub" do
    repo_path = Rails.root.join("tmp", "git_repos", @user.id.to_s, "#{@repo_name}")
    FileUtils.mkdir_p(repo_path)
    FileUtils.touch(File.join(repo_path, "test.rb"))

    service = mock_command_execution(@generated_app)
    service.expects(:execute).returns(true)

    repo_response = GitRepo.new(html_url: "https://github.com/test-user/#{@repo_name}")
    app_repo_service = mock("app_repo_service")
    app_repo_service.expects(:initialize_repository).tap { |x|
      @generated_app.create_github_repo!
      @generated_app.generate!
      @generated_app.update!(
        github_repo_name: @repo_name,
        github_repo_url: repo_response.html_url
      )
    }.returns(repo_response)

    app_repo_service.stubs(:push_app_files).returns(true)
    app_repo_service.stubs(:commit_changes).returns(true)
    AppRepositoryService.expects(:new).returns(app_repo_service)

    orchestrator = mock("orchestrator")
    orchestrator.expects(:perform_generation).tap { |x|
      service.execute
    }.returns(true)
    AppGeneration::Orchestrator.expects(:new).returns(orchestrator)

    AppStatus.any_instance.stubs(:broadcast_status_steps).returns(true)
    AppStatus.any_instance.stubs(:broadcast_status_change).returns(true)
    AppStatus.any_instance.stubs(:notify_status_change).returns(true)
    AppStatus.any_instance.stubs(:update_generated_app_build_time).returns(true)

    AppGenerationJob.perform_now(@generated_app.id)

    @generated_app.reload

    @generated_app.source_path = @source_path.to_s
    assert_equal "completed", @generated_app.app_status.status
    assert_equal "https://github.com/test-user/#{@repo_name}", @generated_app.github_repo_url
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
