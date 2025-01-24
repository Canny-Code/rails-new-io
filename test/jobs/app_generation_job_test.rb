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

    # Set up the workflow sequence
    workflow = sequence("workflow")

    # Mock all external service calls to succeed
    app_repo_service = mock
    AppRepositoryService.expects(:new).with(@generated_app).returns(app_repo_service)

    initialize_repository = -> {
      @generated_app.create_github_repo!
      true
    }
    app_repo_service.expects(:initialize_repository).in_sequence(workflow).returns(initialize_repository.call)

    orchestrator = mock
    AppGeneration::Orchestrator.expects(:new).with(@generated_app).returns(orchestrator)

    perform_generation = -> {
      @generated_app.generate!
      true
    }
    orchestrator.expects(:perform_generation).in_sequence(workflow).returns(perform_generation.call)

    # Mock GeneratedApp.find to return our app
    GeneratedApp.expects(:find).with(@generated_app.id).returns(@generated_app)

    # Mock the sync steps in sequence
    push_to_github = -> {
      @generated_app.app_status.start_github_push!
      true
    }
    @generated_app.expects(:push_to_github!).in_sequence(workflow).returns(push_to_github.call)

    initial_git_commit = -> {
      true
    }
    @generated_app.expects(:initial_git_commit).in_sequence(workflow).returns(initial_git_commit.call)

    sync_to_git = -> {
      true
    }
    @generated_app.expects(:sync_to_git).in_sequence(workflow).returns(sync_to_git.call)

    # This needs to be an expectation, not a stub, to ensure it's called
    @generated_app.expects(:start_ci!).in_sequence(workflow).raises(StandardError.new(error_message))

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
end
