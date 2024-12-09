require "test_helper"
require "ostruct"

class CommandExecutionServiceTest < ActiveSupport::TestCase
  def setup
    @generated_app = generated_apps(:blog_app)
    @generated_app.create_app_status! # Ensure app_status exists for logger
    @valid_commands = [
      "rails new #{@generated_app.name} -d postgres --css=tailwind --skip-bootsnap",
      "rails new #{@generated_app.name} --skip-action-mailbox --skip-jbuilder --asset-pipeline=propshaft --javascript=esbuild --css=tailwind --skip-spring"
    ]
    @service = CommandExecutionService.new(@generated_app, @valid_commands.first)
  end

  test "executes valid rails new command" do
    output = "Sample output"
    error = "Sample error"

    @valid_commands.each do |command|
      # Store the current count to only delete new entries
      initial_count = @generated_app.log_entries.count

      service = CommandExecutionService.new(@generated_app, command)

      Open3.stub :popen3, mock_popen3(output, error, success: true) do
        assert_difference -> { @generated_app.log_entries.count }, 7 do
          service.execute
        end

        log_entries = @generated_app.log_entries.order(created_at: :asc).offset(initial_count)

        expected_messages = [
          "Validating command: #{command}",
          "Command validation successful",
          "Created temporary directory",
          "Preparing to execute command",
          "System environment details",
          "Environment variables for command execution",
          "Sample output"
        ]

        expected_messages.each_with_index do |message, index|
          assert_equal message, log_entries[index].message, "Log entry #{index} doesn't match for command: #{command}"
        end

        # Verify the final buffer content
        buffer_entry = log_entries.find { |entry| entry.metadata["stream"] == "stdout" }
        assert_equal "Sample output", buffer_entry.message

        # Verify specific log levels
        assert log_entries.all?(&:info?)

        # Clean up only the entries from this iteration
        @generated_app.log_entries.where("id > ?", @generated_app.log_entries.limit(initial_count).pluck(:id).last).destroy_all
      end
    end
  end

  test "validates app name matches GeneratedApp name" do
    wrong_name = "wrong-app-name"
    invalid_command = "rails new #{wrong_name} -d postgres"

    assert_difference -> { AppGeneration::LogEntry.count }, 2 do # Expect both validation start and error logs
      error = assert_raises(CommandExecutionService::InvalidCommandError) do
        CommandExecutionService.new(@generated_app, invalid_command)
      end
      assert_equal "App name in command must match GeneratedApp name", error.message
    end

    log_entries = @generated_app.log_entries.order(created_at: :desc).limit(2)
    assert log_entries[0].error?
    assert_equal "Invalid app name", log_entries[0].message
    assert_equal({
      "command" => invalid_command,
      "expected" => @generated_app.name,
      "actual" => wrong_name
    }, log_entries[0].metadata)

    assert log_entries[1].info?
    assert_match /Validating command/, log_entries[1].message
  end

  test "raises error for invalid commands" do
    assert_difference -> { AppGeneration::LogEntry.count }, 2 do # Expect both validation start and error logs
      error = assert_raises(CommandExecutionService::InvalidCommandError) do
        CommandExecutionService.new(@generated_app, "rm -rf /")
      end
      assert_equal "Command must start with 'rails new'", error.message
    end

    log_entries = @generated_app.log_entries.order(created_at: :desc).limit(2)
    assert log_entries[0].error?
    assert_equal "Invalid command prefix", log_entries[0].message

    assert log_entries[1].info?
    assert_match /Validating command/, log_entries[1].message
  end

  test "validates command format" do
    invalid_commands = {
      "rails new; rm -rf /" => [ "Command contains invalid characters", "Command injection attempt detected" ],
      "rails new --invalid-flag" => [ "Invalid command format", "Invalid command format" ],
      "rails generate model User" => [ "Command must start with 'rails new'", "Invalid command prefix" ],
      "rails new" => [ "Invalid command format", "Invalid command format" ]
    }

    invalid_commands.each do |cmd, (expected_message, expected_log)|
      assert_difference -> { AppGeneration::LogEntry.count }, 2 do # Expect both validation start and error logs
        error = assert_raises(CommandExecutionService::InvalidCommandError) do
          CommandExecutionService.new(@generated_app, cmd)
        end
        assert_equal expected_message, error.message

        log_entries = @generated_app.log_entries.order(created_at: :desc).limit(2)
        assert log_entries[0].error?
        assert_equal expected_log, log_entries[0].message
        assert_equal cmd, log_entries[0].metadata["command"]

        assert log_entries[1].info?
        assert_match /Validating command/, log_entries[1].message
      end
    end
  end

  test "handles timeouts" do
    @service.stub :run_isolated_process, -> { raise Timeout::Error } do
      assert_difference -> { AppGeneration::LogEntry.count }, 1 do
        assert_raises(Timeout::Error) { @service.execute }
      end

      log_entries = @generated_app.log_entries.order(created_at: :desc).limit(1)
      assert_equal "Created temporary directory", log_entries[0].message
      assert log_entries.all? { |entry| entry.info? }
    end
  end

  test "logs command output" do
    output = "Sample output"
    error = "Sample error"

    Open3.stub :popen3, mock_popen3(output, error, success: true) do
      assert_difference -> { AppGeneration::LogEntry.count }, 7 do
        @service.execute
      end

      log_entries = @generated_app.log_entries.order(created_at: :desc).limit(7)

      assert_equal "Rails app generation process finished successfully", log_entries[0].message
      assert_equal "Rails app generation process started", log_entries[1].message
      assert_equal "Sample output", log_entries[2].message
      assert_equal "Environment variables for command execution", log_entries[3].message
      assert_equal "System environment details", log_entries[4].message
      assert_equal "Preparing to execute command", log_entries[5].message
      assert_equal "Created temporary directory", log_entries[6].message

      # Fix: Look for the log entry with stdout stream
      buffer_entry = log_entries.find { |entry| entry.metadata["stream"] == "stdout" }
      assert_equal "Sample output", buffer_entry.message
    end
  end

  test "logs command errors" do
    output = ""
    error = "Error message"

    Open3.stub :popen3, mock_popen3(output, error, success: false) do
      assert_difference -> { AppGeneration::LogEntry.count }, 7 do
        assert_raises(RuntimeError) { @service.execute }
      end

      log_entries = @generated_app.log_entries.recent_first

      # Verify the sequence of logs
      expected_messages = [
        "Command failed",
        "No output",  # From Buffer's default message
        "Rails app generation process started",
        "Environment variables for command execution",
        "System environment details",
        "Preparing to execute command",
        "Created temporary directory",
        "Command validation successful",
        "Validating command: #{@command}"
      ]

      expected_messages.each do |message|
        assert log_entries.any? { |entry| entry.message.include?(message) },
          "Expected to find log entry containing '#{message}'"
      end

      # Verify error details
      error_log = log_entries.find { |entry| entry.message == "Command failed" }
      assert error_log.error?
      assert_equal "No output", error_log.metadata["output"]
      assert error_log.metadata["status"]
    end
  end

  test "terminates running process during cleanup" do
    output = "Sample output"
    error = "Sample error"
    pid = 12345

    Process.stub :kill, ->(signal, process_pid) {
      assert_equal 0, signal if signal == 0
      assert_equal "TERM", signal if signal == "TERM"
      assert_equal pid, process_pid
    } do
      Open3.stub :popen3, mock_popen3(output, error, success: true, pid: pid) do
        assert_difference -> { AppGeneration::LogEntry.count }, 8 do
          @service.execute
        end

        log_entries = @generated_app.log_entries.order(created_at: :desc)

        # Verify all expected messages are present
        expected_messages = [
          "Terminated process",
          "Rails app generation process finished successfully",
          "Sample output",  # Buffer output
          "Rails app generation process started",
          "Environment variables for command execution",
          "System environment details",
          "Preparing to execute command",
          "Created temporary directory",
          "Command validation successful",
          "Validating command: #{@command}"
        ]

        expected_messages.each do |message|
          assert log_entries.any? { |entry| entry.message.include?(message) },
            "Expected to find log entry containing '#{message}'"
        end

        # Verify process termination log
        termination_log = log_entries.find { |entry| entry.message == "Terminated process" }
        assert termination_log
        assert_equal pid, termination_log.metadata["pid"]
      end
    end
  end

  private

  def mock_popen3(stdout, stderr, success: true, pid: 12345)
    lambda do |env, command, **options, &block|
      mock_stdin = StringIO.new
      mock_stdout = StringIO.new(stdout)
      mock_stderr = StringIO.new(stderr)
      mock_wait_thread = OpenStruct.new(
        pid: pid,
        value: OpenStruct.new(success?: success)
      )

      block.call(mock_stdin, mock_stdout, mock_stderr, mock_wait_thread)
    end
  end
end
