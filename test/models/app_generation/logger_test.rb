require "test_helper"

module AppGeneration
  class LoggerTest < ActiveSupport::TestCase
    def setup
      @generated_app = generated_apps(:blog_app)
      @logger = Logger.new(@generated_app)
    end

    test "creates info log entry" do
      assert_difference -> { LogEntry.count } do
        @logger.info("Test message")
      end

      entry = LogEntry.last

      assert entry.info?
      assert_equal @generated_app.status, entry.phase
      assert_equal "Test message", entry.message
    end

    test "creates warning log entry" do
      assert_difference -> { LogEntry.count } do
        @logger.warn("Warning message")
      end

      entry = LogEntry.last
      assert entry.warn?
    end

    test "creates error log entry" do
      assert_difference -> { LogEntry.count } do
        @logger.error("Error message")
      end

      entry = LogEntry.last
      assert entry.error?
    end

    test "stores metadata" do
      metadata = { "command" => "rails new", "duration" => 1.5 }
      @logger.info("Message with metadata", metadata)

      entry = LogEntry.last
      assert_equal metadata, entry.metadata
    end
  end
end
