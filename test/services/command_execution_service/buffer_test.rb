require "test_helper"

class CommandExecutionService
  class BufferTest < ActiveSupport::TestCase
    test "updates log entry message without changing entry_type when not completed" do
      generated_app = GeneratedApp.create!(
        name: "test-app",
        user: users(:john),
        ruby_version: "3.2.0",
        rails_version: "7.1.0"
      )

      buffer = CommandExecutionService::Buffer.new(generated_app)
      buffer.append("First message")
      buffer.append("Second message")

      # Force a flush without completing
      buffer.flush

      log_entry = AppGeneration::LogEntry.last
      assert_equal "First message\nSecond message", log_entry.message
      assert_equal "rails_output", log_entry.entry_type
    end
  end
end
