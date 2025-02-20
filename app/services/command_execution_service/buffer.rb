class CommandExecutionService
  class Buffer
    FLUSH_INTERVAL = 1.second

    def initialize(generated_app, command)
      @generated_app = generated_app
      @command = command
      @mutex = Mutex.new
      @output = []
      @log_entry = create_initial_log_entry
      @last_flush = Time.current
      @completed = false
    end

    def append(message)
      should_flush = false

      synchronize do
        @output << message
        should_flush = should_flush?
      end

      flush if should_flush
    end

    def complete!
      @completed = true
      flush
    end

    def flush
      synchronize do
        return if @output.empty?

        new_content = @output.join("\n")

        appended_message = String.new(capacity: @log_entry.message.bytesize + new_content.bytesize + 1).tap do |buffer|
          buffer << @log_entry.message << "\n" << new_content
        end

        @log_entry.update!(
          message: appended_message,
          phase: @generated_app.status
        )

        @output.clear
        @last_flush = Time.current
      end
    end

    private

    def create_initial_log_entry
      AppGeneration::LogEntry.create!(
        generated_app: @generated_app,
        level: :info,
        message: "Command execution started: `#{@command}`",
        metadata: { stream: :stdout, is_rails_output: true },
        phase: @generated_app.status,
        entry_type: "rails_output"
      )
    end

    def synchronize(&block)
      @mutex.synchronize(&block)
    end

    def should_flush?
      # Flush if enough time has passed OR if buffer is getting large
      Time.current - @last_flush >= FLUSH_INTERVAL || @output.length >= 20
    end
  end
end
