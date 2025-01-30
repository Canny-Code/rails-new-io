require "test_helper"

class AppGenerationJobTest < ActiveSupport::TestCase
  setup do
    @generated_app = generated_apps(:pending_app)
    @logger = AppGeneration::Logger.new(@generated_app)
    AppGeneration::Logger.stubs(:new).returns(@logger)
  end

  test "marks app as failed and raises error when github repository creation fails" do
    error_message = "Repository creation failed"
    orchestrator = mock
    app_status = mock

    @generated_app.stubs(:app_status).returns(app_status)
    app_status.expects(:failed?).returns(true)  # Return true after we've called fail!

    AppGeneration::Orchestrator.expects(:new).with(@generated_app).returns(orchestrator)
    orchestrator.expects(:create_github_repository).raises(StandardError.new(error_message))
    orchestrator.expects(:handle_error).with(instance_of(StandardError))

    error = assert_raises StandardError do
      AppGenerationJob.perform_now(@generated_app.id)
    end

    assert_equal error_message, error.message
    assert @generated_app.reload.app_status.failed?
  end
end
