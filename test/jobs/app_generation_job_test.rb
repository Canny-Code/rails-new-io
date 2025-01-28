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
    app_repo_service.expects(:create_github_repository).raises(StandardError.new(error_message))

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
