module AppGeneration
  class Logger
    def initialize(app_status)
      @app_status = app_status
      raise ArgumentError, "AppStatus is required" unless @app_status
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
        generated_app: @app_status.generated_app,
        level: level,
        phase: @app_status.status,
        message: message,
        metadata: metadata
      )
    end
  end
end
