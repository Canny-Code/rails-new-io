require "test_helper"

class AppGenerationJobTest < ActiveSupport::TestCase
  setup do
    @generated_app = generated_apps(:pending_app)
    @logger = AppGeneration::Logger.new(@generated_app)
    AppGeneration::Logger.stubs(:new).returns(@logger)
  end

  test "marks app as failed and raises error when github repository creation fails" do
    error_message = "Repository creation failed"
    github_repo_service = mock

    GithubRepositoryService.expects(:new).with(@generated_app).returns(github_repo_service)
    github_repo_service.expects(:create_repository).raises(StandardError.new(error_message))

    # Expect error logs in the correct sequence
    sequence = sequence("error_logging")
    @logger.expects(:error).with(
      "App generation failed: #{error_message}"
    ).in_sequence(sequence)
    @logger.expects(:error).with(
      "Failed to execute workflow",
      has_entries(error: error_message, backtrace: instance_of(Array))
    ).in_sequence(sequence)

    error = assert_raises StandardError do
      AppGenerationJob.perform_now(@generated_app.id)
    end

    assert_equal error_message, error.message
  end

  test "marks app as failed and raises error when CI start fails" do
    error_message = "CI start failed"
    github_repo_service = mock

    GithubRepositoryService.expects(:new).with(@generated_app).returns(github_repo_service)
    github_repo_service.expects(:create_repository).raises(StandardError.new(error_message))

    # Expect error logs in the correct sequence
    sequence = sequence("error_logging")
    @logger.expects(:error).with(
      "App generation failed: #{error_message}"
    ).in_sequence(sequence)
    @logger.expects(:error).with(
      "Failed to execute workflow",
      has_entries(error: error_message, backtrace: instance_of(Array))
    ).in_sequence(sequence)

    error = assert_raises StandardError do
      AppGenerationJob.perform_now(@generated_app.id)
    end

    assert_equal error_message, error.message
  end
end
