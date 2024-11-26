module AppGeneration
  class Logger
    def initialize(generated_app)
      @generated_app = generated_app
      raise ArgumentError, "GeneratedApp must have an app_status" unless @generated_app.app_status
    end

    def info(message, metadata = {})
      create_entry(:info, message, metadata)
    end

    def warn(message, metadata = {})
      create_entry(:warn, message, metadata)
    end

    def error(message, metadata = {})
      create_entry(:error, message, metadata)
    end

    private

    def create_entry(level, message, metadata)
      LogEntry.create!(
        generated_app: @generated_app,
        level: level,
        phase: @generated_app.app_status.status,
        message: message,
        metadata: metadata
      )
    end
  end
end
