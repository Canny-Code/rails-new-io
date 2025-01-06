class CommandExecutionService
  class Buffer
    FLUSH_INTERVAL = 1.second

    def initialize(generated_app)
      @generated_app = generated_app
      @mutex = Mutex.new
      @output = []
      @log_entry = create_initial_log_entry
      @last_flush = Time.current
      @completed = false
      Rails.logger.debug "%%%%% Buffer initialized with log entry #{@log_entry.id}"
    end

    def append(message)
      should_flush = false

      synchronize do
        Rails.logger.debug "%%%%% Buffer append: Adding message of length #{message.length}"
        @output << message
        should_flush = should_flush?
      end

      flush if should_flush
    end

    def complete!
      Rails.logger.debug "%%%%% Buffer complete! called"
      @completed = true
      flush
    end

    def flush
      synchronize do
        return if @output.empty?

        Rails.logger.debug "%%%%% Buffer flush: Current entry: #{@log_entry&.id}, buffer size: #{@output.length}"

        if @log_entry.nil?
          @log_entry = create_initial_log_entry
          Rails.logger.debug "%%%%% Created new log entry: #{@log_entry.id}"
        end

        new_content = @output.join("\n")
        message = @log_entry.message.present? ? "#{@log_entry.message}\n#{new_content}" : new_content
        Rails.logger.debug "%%%%% Updating log entry #{@log_entry.id} with message length: #{message.length}"

        @log_entry.update!(
          message: message,
          phase: @generated_app.status
        )

        @output.clear
        @last_flush = Time.current
      end
    end

    def message
      @log_entry&.message
    end

    private

    def create_initial_log_entry
      AppGeneration::LogEntry.create!(
        generated_app: @generated_app,
        level: :info,
        message: "Initializing Rails application generation...",
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
