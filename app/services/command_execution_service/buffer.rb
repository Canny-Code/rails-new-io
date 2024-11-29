class CommandExecutionService
  class Buffer
    FLUSH_INTERVAL = 1.second

    def initialize(generated_app, stream_type)
      @generated_app = generated_app
      @stream_type = stream_type
      @entries = []
      @mutex = Mutex.new
      @output = []
    end

    def append(message)
      synchronize do
        @output << message
        entries << {
          level: @stream_type == :stderr ? :error : :info,
          message: message,
          metadata: { stream: @stream_type },
          timestamp: Time.current
        }
      end
    end

    def flush
      synchronize do
        entries.each do |entry|
          AppGeneration::LogEntry.create!(
            generated_app: @generated_app,
            level: entry[:level],
            message: entry[:message],
            metadata: entry[:metadata],
            phase: @generated_app.status,
            created_at: entry[:timestamp]
          )
        end
        entries.clear
      end
    end

    def join(separator = "\n")
      synchronize do
        @output.join(separator)
      end
    end

    private

    attr_reader :entries

    def synchronize(&block)
      @mutex.synchronize(&block)
    end
  end
end
