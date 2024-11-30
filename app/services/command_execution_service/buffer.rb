class CommandExecutionService
  class Buffer
    FLUSH_INTERVAL = 1.second

    def initialize(generated_app)
      @generated_app = generated_app
      @mutex = Mutex.new
      @output = []
      @log_entry = create_initial_log_entry
      @last_flush = Time.current
    end

    def append(message)
      should_flush = false

      synchronize do
        @output << message
        should_flush = should_flush?
      end

      flush if should_flush
    end

    def flush
      message = nil

      synchronize do
        message = @output.join("\n")
        message = "No output" if message.blank?
      end

      @log_entry.update!(
        message: message,
        phase: @generated_app.status
      )

      synchronize do
        @last_flush = Time.current
      end
    end

    def join(separator = "\n")
      synchronize do
        @output.join(separator)
      end
    end

    private

    def create_initial_log_entry
      AppGeneration::LogEntry.create!(
        generated_app: @generated_app,
        level: :info,
        message: "Initializing Rails application generation...",
        metadata: { stream: :stdout },
        phase: @generated_app.status
      )
    end

    def synchronize(&block)
      @mutex.synchronize(&block)
    end

    def should_flush?
      Time.current - @last_flush >= FLUSH_INTERVAL
    end
  end
end
