require "test_helper"
require_relative "../../../app/services/app_generation/errors"

module AppGeneration
  class OrchestratorTest < ActiveSupport::TestCase
    setup do
      @generated_app = generated_apps(:pending_app)
      @orchestrator = Orchestrator.new(@generated_app)
    end

    test "enqueues generation job when app is in pending state" do
      assert @generated_app.pending?

      assert_difference -> { SolidQueue::Job.count } do
        assert @orchestrator.call
      end

      job = SolidQueue::Job.last
      assert_equal "AppGenerationJob", job.class_name
      assert_equal [ @generated_app.id ], job.arguments["arguments"]
    end

    test "validates app must be in pending state" do
      @generated_app.app_status.update!(status: "generating")
      @generated_app.reload

      assert_equal "generating", @generated_app.status
      assert_not @generated_app.pending?

      error = assert_raises(AppGeneration::InvalidStateError) do
        @orchestrator.call
      end

      assert_equal "App must be in pending state to start generation", error.message
    end

    test "handles and logs errors during orchestration" do
      error_message = "Something went wrong"
      AppGenerationJob.stubs(:perform_later).raises(StandardError.new(error_message))

      # Expect both error logs in sequence
      sequence = sequence("error_logging")
      AppGeneration::Logger.any_instance.expects(:error).with(
        "Failed to start app generation",
        { error: error_message }
      ).in_sequence(sequence)
      AppGeneration::Logger.any_instance.expects(:error).with(
        "App generation failed: #{error_message}"
      ).in_sequence(sequence)

      assert_not @orchestrator.call
      assert @generated_app.reload.failed?
      assert_equal error_message, @generated_app.app_status.error_message
    end
  end
end
