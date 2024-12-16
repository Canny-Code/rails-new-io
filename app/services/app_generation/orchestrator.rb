module AppGeneration
  class Orchestrator
    def initialize(generated_app)
      @generated_app = generated_app
      @logger = AppGeneration::Logger.new(generated_app)
    end

    def call
      validate_initial_state!

      AppGenerationJob.perform_later(@generated_app.id)

      true
    rescue AppGeneration::InvalidStateError
      raise
    rescue StandardError => e
      @logger.error("Failed to start app generation", { error: e.message })
      @generated_app.mark_as_failed!(e.message)
      false
    end

    private

    def validate_initial_state!
      raise AppGeneration::InvalidStateError, "App must be in pending state to start generation" unless @generated_app.pending?
    end
  end
end
