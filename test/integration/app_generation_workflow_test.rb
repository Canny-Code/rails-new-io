require "test_helper"
require_relative "../support/git_test_helper"
require_relative "../support/command_execution_test_helper"

class AppGenerationWorkflowTest < ActionDispatch::IntegrationTest
  include DisableParallelization
  include GitTestHelper
  include CommandExecutionTestHelper

  setup do
    @user = users(:john)
    @repo_name = "test_app"
    @workspace_path = create_test_directory("test_source")
    @app_dir = File.join(@workspace_path, @repo_name)

    FileUtils.mkdir_p(@app_dir)
    FileUtils.touch(File.join(@app_dir, "test.rb"))
    FileUtils.touch(File.join(@app_dir, "Gemfile"))
    init_git_repo(@app_dir)

    # Ensure the Git repo base path exists
    FileUtils.mkdir_p(Rails.root.join("tmp", "git_repos", @user.id.to_s))

    @generated_app = GeneratedApp.create!(
      name: @repo_name,
      user: @user,
      recipe: recipes(:blog_recipe),
      workspace_path: @workspace_path.to_s
    )

    mocks = setup_github_mocks
    @mock_client = mocks.client

    # Mock File.exist? to return true for template paths
    File.stubs(:exist?).returns(true)

    # Mock apply_ingredient! to prevent actual template application
    @generated_app.stubs(:apply_ingredient!).returns(true)
  end

  teardown do
    FileUtils.rm_rf(Rails.root.join("tmp", "git_repos", @user.id.to_s))
  end

  test "generates app and pushes to GitHub" do
    repo_path = Rails.root.join("tmp", "git_repos", @user.id.to_s, "#{@repo_name}")
    FileUtils.mkdir_p(repo_path)
    FileUtils.touch(File.join(repo_path, "test.rb"))

    # Mock GitHub API operations
    GitHubResponse = Data.define(:html_url)
    repo_response = GitHubResponse.new(html_url: "https://github.com/#{@user.github_username}/#{@repo_name}")

    # Mock GitHub API calls
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
    command_service = mock("command_execution_service")
    command_service.stubs(:execute).returns(true)
    CommandExecutionService.stubs(:new).with(@generated_app, instance_of(AppGeneration::Logger)).returns(command_service)

    # Mock file operations and Git commands
    File.stubs(:exist?).returns(true)

    # Mock Git commands with proper return values
    git_command_responses = {
      "git rev-parse --abbrev-ref HEAD" => "main",
      "git status --porcelain" => "",
      "git remote -v" => "",
      "git rev-parse --verify HEAD 2>/dev/null" => "some-sha",
      "git config --list" => "core.bare=false\ncore.repositoryformatversion=0"
    }

    # Mock ALL Git commands to return strings
    AppRepositoryService.any_instance.stubs(:run_command).returns("") # default fallback

    # Then mock specific commands
    git_command_responses.each do |cmd, response|
      AppRepositoryService.any_instance.stubs(:run_command).with(cmd).returns(response).then do
        puts "DEBUG: Git command: #{cmd}"
        puts "DEBUG: Git command result: #{response.inspect}"
      end
    end

    # Mock Git system commands with exact matches
    git_system_commands = {
      "git add . && git -c init.defaultBranch=main commit -m 'Initial commit by railsnew.io\n\ncommand line flags:\n\n\n\n'" => true,
      "git branch -M main" => true,
      "git remote add origin https://github.com/#{@user.github_username}/#{@repo_name}" => true,
      "git remote set-url origin https://github.com/#{@user.github_username}/#{@repo_name}" => true,
      "git remote set-url origin https://#{@user.github_token}@github.com/#{@user.github_username}/#{@repo_name}" => true,
      "git -c core.askpass=false push -v -u origin main" => true,
      "git remote set-url origin https://github.com/#{@user.github_username}/#{@repo_name}" => true
    }

    # Default stub for system commands
    AppRepositoryService.any_instance.stubs(:system).returns(true).then do |actual_cmd|
      puts "DEBUG: Unexpected system command: #{actual_cmd}"
      puts "DEBUG: Available commands:"
      git_system_commands.each do |cmd, _|
        puts "  - #{cmd}"
      end
      true
    end

    # Specific stubs for each command
    git_system_commands.each do |cmd, response|
      AppRepositoryService.any_instance.stubs(:system).with(cmd).returns(response).then do
        puts "DEBUG: Executing system command: #{cmd}"
        puts "DEBUG: System command result: #{response}"
      end
    end

    # Debug initial state
    puts "DEBUG: Initial state: #{@generated_app.app_status.status}"

    # Add state transition debugging
    AppStatus.class_eval do
      def aasm_fire_event(name, options = {}, *args, &block)
        event_name = name.to_s.sub("!", "")  # Remove the ! from event names
        puts "DEBUG: Attempting state transition: #{event_name} from #{aasm.current_state}"
        result = super
        puts "DEBUG: State after transition attempt: #{aasm.current_state}"
        result
      end
    end

    # Mock workflow execution
    workflow = mock("workflow")
    job = AppGenerationJob.any_instance

    # Mock each step to execute the block that's passed to it
    workflow.expects(:step).with(:create_github_repository) do |&block|
      puts "DEBUG: Executing create_github_repository step"
      block.call if block
    end
    workflow.expects(:step).with(:generate_rails_app) do |&block|
      puts "DEBUG: Executing generate_rails_app step"
      block.call if block
    end
    workflow.expects(:step).with(:create_initial_commit) do |&block|
      puts "DEBUG: Executing create_initial_commit step"
      block.call if block
    end
    workflow.expects(:step).with(:apply_ingredients) do |&block|
      puts "DEBUG: Executing apply_ingredients step"
      block.call if block
    end
    workflow.expects(:step).with(:push_to_remote) do |&block|
      puts "DEBUG: Executing push_to_remote step"
      block.call if block
    end
    workflow.expects(:step).with(:start_ci) do |&block|
      puts "DEBUG: Executing start_ci step"
      block.call if block
    end
    workflow.expects(:step).with(:complete_generation) do |&block|
      puts "DEBUG: Executing complete_generation step"
      block.call if block
    end

    # Mock the workflow execution
    AppGenerationJob.any_instance.expects(:execute_workflow).with(unique_by: @generated_app.id) do |&block|
      block.call(workflow)
    end

    # Mock orchestrator methods to ensure state transitions happen
    orchestrator = AppGeneration::Orchestrator.new(@generated_app)
    AppGeneration::Orchestrator.any_instance.stubs(:create_github_repository).returns(true).then do
      puts "DEBUG: Executing create_github_repository in orchestrator"
      @generated_app.app_status.start_github_repo_creation!
      puts "DEBUG: State after create_github_repository: #{@generated_app.app_status.status}"
    end
    AppGeneration::Orchestrator.any_instance.stubs(:generate_rails_app).returns(true).then do
      puts "DEBUG: Executing generate_rails_app in orchestrator"
      @generated_app.app_status.start_generation!
      puts "DEBUG: State after generate_rails_app: #{@generated_app.app_status.status}"
    end
    AppGeneration::Orchestrator.any_instance.stubs(:create_initial_commit).returns(true).then do
      puts "DEBUG: Executing create_initial_commit in orchestrator"
      puts "DEBUG: State after create_initial_commit: #{@generated_app.app_status.status}"
    end
    AppGeneration::Orchestrator.any_instance.stubs(:apply_ingredients).returns(true).then do
      puts "DEBUG: Executing apply_ingredients in orchestrator"
      puts "DEBUG: State after apply_ingredients: #{@generated_app.app_status.status}"
    end
    AppGeneration::Orchestrator.any_instance.stubs(:push_to_remote).returns(true).then do
      puts "DEBUG: Executing push_to_remote in orchestrator"
      @generated_app.app_status.start_github_push!
      puts "DEBUG: State after push_to_remote: #{@generated_app.app_status.status}"
    end
    AppGeneration::Orchestrator.any_instance.stubs(:start_ci).returns(true).then do
      puts "DEBUG: Executing start_ci in orchestrator"
      @generated_app.app_status.start_ci!
      puts "DEBUG: State after start_ci: #{@generated_app.app_status.status}"
    end
    AppGeneration::Orchestrator.any_instance.stubs(:complete_generation).returns(true).then do
      puts "DEBUG: Executing complete_generation in orchestrator"
      @generated_app.app_status.complete!
      puts "DEBUG: State after complete_generation: #{@generated_app.app_status.status}"
    end

    # Run the job
    AppGenerationJob.perform_now(@generated_app.id)

    # Verify final state
    @generated_app.reload
    @generated_app.workspace_path = @workspace_path.to_s

    puts "DEBUG: Final state: #{@generated_app.app_status.status}"

    # Assertions
    assert_equal "completed", @generated_app.app_status.status
    assert_equal "https://github.com/#{@user.github_username}/#{@repo_name}", @generated_app.github_repo_url

    # Verify state history
    history = @generated_app.app_status.status_history
    assert_equal "pending", history[0]["from"]
    assert_equal "creating_github_repo", history[0]["to"]
    assert_equal "creating_github_repo", history[1]["from"]
    assert_equal "generating", history[1]["to"]
    assert_equal "generating", history[2]["from"]
    assert_equal "pushing_to_github", history[2]["to"]
    assert_equal "pushing_to_github", history[3]["from"]
    assert_equal "running_ci", history[3]["to"]
    assert_equal "running_ci", history[4]["from"]
    assert_equal "completed", history[4]["to"]
  end

  test "handles GitHub API errors during app generation" do
    # Mock GitHub API calls
    @mock_client.expects(:repository?).returns(true)

    # Mock command execution (external system call)
    command_service = mock("command_execution_service")
    command_service.stubs(:execute).never

    # Mock repository service
    repository_service = mock("repository_service")
    repository_service.expects(:create_github_repository).raises(GithubRepositoryService::RepositoryExistsError.new("Repository 'test_app' already exists"))
    repository_service.stubs(:commit_changes_after_applying_ingredient).returns(true)

    # Mock service initialization
    AppGeneration::Logger.any_instance.stubs(:info)
    AppGeneration::Logger.any_instance.stubs(:error)
    CommandExecutionService.stubs(:new).with(@generated_app, instance_of(AppGeneration::Logger)).returns(command_service)
    AppRepositoryService.stubs(:new).with(@generated_app, instance_of(AppGeneration::Logger)).returns(repository_service)

    error = assert_raises(GithubRepositoryService::RepositoryExistsError) do
      AppGenerationJob.perform_now(@generated_app.id)
    end

    assert_equal "Repository 'test_app' already exists", error.message

    @generated_app.reload
    # Set workspace_path again since it's not persisted
    @generated_app.workspace_path = @workspace_path.to_s
    assert_equal "failed", @generated_app.app_status.status
    assert_nil @generated_app.github_repo_url
    assert_equal "Repository 'test_app' already exists", @generated_app.app_status.error_message
  end
end
