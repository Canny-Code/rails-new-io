require "test_helper"

class AppGenerationJobTest < ActiveSupport::TestCase
  setup do
    @generated_app = generated_apps(:pending_app)
    @logger = AppGeneration::Logger.new(@generated_app)
    AppGeneration::Logger.stubs(:new).returns(@logger)
  end

  test "marks app as failed and raises error when github repository creation fails" do
    error_message = "Repository creation failed"
    app_repo_service = mock

    AppRepositoryService.expects(:new).with(@generated_app).returns(app_repo_service)
    app_repo_service.expects(:initialize_repository).raises(StandardError.new(error_message))

    # Expect error logs in the correct sequence
    error_sequence = sequence("error_logging")
    @logger.expects(:error).with(
      "App generation failed: #{error_message}"
    ).in_sequence(error_sequence)
    @logger.expects(:error).with(
      "Failed to execute workflow",
      has_entries(error: error_message, backtrace: instance_of(Array))
    ).in_sequence(error_sequence)

    error = assert_raises StandardError do
      AppGenerationJob.perform_now(@generated_app.id)
    end

    assert_equal error_message, error.message
    assert @generated_app.reload.app_status.failed?
  end

  test "marks app as failed and raises error when CI start fails" do
    error_message = "CI start failed"

    puts "DEBUG: Initial state: #{@generated_app.status}"

    # Set up the workflow sequence
    workflow = sequence("workflow")

    # Mock all external service calls to succeed
    app_repo_service = mock.tap { puts "DEBUG: Created app_repo_service mock" }
    AppRepositoryService.expects(:new).with(@generated_app).returns(app_repo_service).tap { puts "DEBUG: Set up AppRepositoryService.new expectation" }

    initialize_repository = -> {
      puts "DEBUG: Inside initialize_repository mock"
      puts "DEBUG: Before create_github_repo!: #{@generated_app.status}"
      @generated_app.create_github_repo!
      puts "DEBUG: After create_github_repo!: #{@generated_app.status}"
      true
    }
    app_repo_service.expects(:initialize_repository).in_sequence(workflow).returns(initialize_repository.call).tap { puts "DEBUG: Set up initialize_repository expectation" }

    orchestrator = mock.tap { puts "DEBUG: Created orchestrator mock" }
    AppGeneration::Orchestrator.expects(:new).with(@generated_app).returns(orchestrator).tap { puts "DEBUG: Set up Orchestrator.new expectation" }

    perform_generation = -> {
      puts "DEBUG: Inside perform_generation mock"
      puts "DEBUG: Before generate!: #{@generated_app.status}"
      @generated_app.generate!
      puts "DEBUG: After generate!: #{@generated_app.status}"
      true
    }
    orchestrator.expects(:perform_generation).in_sequence(workflow).returns(perform_generation.call).tap { puts "DEBUG: Set up perform_generation expectation" }

    # Mock GeneratedApp.find to return our app
    GeneratedApp.expects(:find).with(@generated_app.id).returns(@generated_app).tap { puts "DEBUG: Set up GeneratedApp.find expectation" }

    # Mock the sync steps in sequence
    push_to_github = -> {
      puts "DEBUG: Inside push_to_github! mock"
      puts "DEBUG: Before push_to_github! state: #{@generated_app.status}"
      @generated_app.app_status.start_github_push!
      puts "DEBUG: After push_to_github! state: #{@generated_app.status}"
      true
    }
    @generated_app.expects(:push_to_github!).in_sequence(workflow).returns(push_to_github.call).tap { puts "DEBUG: Set up push_to_github! expectation" }

    initial_git_commit = -> {
      puts "DEBUG: Inside initial_git_commit mock"
      puts "DEBUG: State during initial_git_commit: #{@generated_app.status}"
      true
    }
    @generated_app.expects(:initial_git_commit).in_sequence(workflow).returns(initial_git_commit.call).tap { puts "DEBUG: Set up initial_git_commit expectation" }

    sync_to_git = -> {
      puts "DEBUG: Inside sync_to_git mock"
      puts "DEBUG: State during sync_to_git: #{@generated_app.status}"
      true
    }
    @generated_app.expects(:sync_to_git).in_sequence(workflow).returns(sync_to_git.call).tap { puts "DEBUG: Set up sync_to_git expectation" }

    # This needs to be an expectation, not a stub, to ensure it's called
    @generated_app.expects(:start_ci!).in_sequence(workflow).raises(StandardError.new(error_message)).tap { puts "DEBUG: Set up start_ci! expectation" }

    puts "DEBUG: Before perform_now: #{@generated_app.status}"

    # Expect error logs in the correct sequence
    error_sequence = sequence("error_logging")
    @logger.expects(:error).with(
      "App generation failed: #{error_message}"
    ).in_sequence(error_sequence).tap { puts "DEBUG: Set up first error logging expectation" }
    @logger.expects(:error).with(
      "Failed to execute workflow",
      has_entries(error: error_message, backtrace: instance_of(Array))
    ).in_sequence(error_sequence).tap { puts "DEBUG: Set up second error logging expectation" }

    error = assert_raises StandardError do
      puts "DEBUG: About to call perform_now"
      AppGenerationJob.perform_now(@generated_app.id).tap { puts "DEBUG: Called perform_now" }
    end

    puts "DEBUG: After perform_now error: #{error.message}"
    puts "DEBUG: Final state: #{@generated_app.status}"
    puts "DEBUG: Final app_status: #{@generated_app.reload.app_status.inspect}"
    assert_equal error_message, error.message
    assert @generated_app.reload.app_status.failed?
  end
end
