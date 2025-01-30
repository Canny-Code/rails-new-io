require "test_helper"
require "ostruct"

class CommandExecutionServiceTest < ActiveSupport::TestCase
  def setup
    @user = users(:john)
    @recipe = recipes(:blog_recipe)
    @temp_dir = Dir.mktmpdir

    @logger = mock("logger")
    @logger.stubs(:info).with { |message, metadata = {}| @generated_app.log_entries.create!(message: message, metadata: metadata, level: :info, phase: :generating) }
    @logger.stubs(:error).with { |message, metadata = {}| @generated_app.log_entries.create!(message: message, metadata: metadata, level: :error, phase: :generating) }
    AppGeneration::Logger.stubs(:new).returns(@logger)

    # Use an existing app and reset its status
    @generated_app = generated_apps(:pending_app)
    @generated_app.update!(workspace_path: @temp_dir)
    @app_status = @generated_app.app_status
    @app_status.update!(
      status: "creating_github_repo",
      status_history: [],
      started_at: nil,
      completed_at: nil,
      error_message: nil
    )

    @valid_commands = [
      "rails new #{@generated_app.name} -d postgres --css=tailwind --skip-bootsnap",
      "rails new #{@generated_app.name} --skip-action-mailbox --skip-jbuilder --asset-pipeline=propshaft --javascript=esbuild --css=tailwind --skip-spring"
    ]

    # Initialize service with the first valid command
    @service = CommandExecutionService.new(@generated_app, @logger, @valid_commands.first)
  end

  def teardown
    FileUtils.rm_rf(@temp_dir) if @temp_dir && Dir.exist?(@temp_dir)
  end

  test "executes valid rails new command" do
    output = "Sample output"
    error = "Sample error"

    @valid_commands.each do |command|
      # Reset app state before each command
      @app_status.update!(
        status: "creating_github_repo",
        status_history: [],
        started_at: nil,
        completed_at: nil,
        error_message: nil
      )

      initial_count = @generated_app.log_entries.count
      service = CommandExecutionService.new(@generated_app, @logger, command)

      puts "DEBUG: Initial log entry count: #{initial_count}"

      Open3.stub :popen3, mock_popen3(output, error, success: true) do
        puts "DEBUG: Before execution - log entries count: #{@generated_app.log_entries.count}"

        assert_difference -> { @generated_app.log_entries.count }, 8 do
          service.execute
        end

        puts "DEBUG: After execution - log entries count: #{@generated_app.log_entries.count}"
        puts "DEBUG: Log entries messages:"
        @generated_app.log_entries.order(created_at: :asc).offset(initial_count).each do |entry|
          puts "DEBUG: - #{entry.message} (#{entry.level})"
        end

        log_entries = @generated_app.log_entries.order(created_at: :asc).offset(initial_count)

        expected_messages = [
          "Validating command: #{command}",
          "Command validation successful",
          "Starting app generation",
          "Created temporary directory",
          "Preparing to execute command",
          "System environment details",
          "Environment variables for command execution",
          "Initializing Rails application generation...\nSample output",
          "Rails app generation process started"
        ]

        expected_messages.each_with_index do |message, index|
          assert_equal message, log_entries[index].message, "Log entry #{index} doesn't match for command: #{command}"
        end

        buffer_entry = log_entries.find { |entry| entry.metadata["stream"] == "stdout" }
        assert_equal "Initializing Rails application generation...\nSample output", buffer_entry.message
        assert log_entries.all?(&:info?)

        @generated_app.log_entries.where("id > ?", @generated_app.log_entries.limit(initial_count).pluck(:id).last).destroy_all
      end
    end
  end

  test "validates app name matches GeneratedApp name" do
    wrong_name = "wrong-app-name"
    invalid_command = "rails new #{wrong_name} -d postgres"

    assert_difference -> { AppGeneration::LogEntry.count }, 2 do # Expect both validation start and error logs
      error = assert_raises(CommandExecutionService::InvalidCommandError) do
        CommandExecutionService.new(@generated_app, @logger, invalid_command)
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
        CommandExecutionService.new(@generated_app, @logger, "rm -rf /")
      end
      assert_equal "Command must start with one of: rails new, bin/rails app:template", error.message
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
      "rails new --invalid-flag" => [ "Invalid rails new command format", "Invalid rails new command format" ],
      "rails generate model User" => [ "Command must start with one of: rails new, bin/rails app:template", "Invalid command prefix" ],
      "rails new" => [ "Invalid rails new command format", "Invalid rails new command format" ]
    }

    invalid_commands.each do |cmd, (expected_message, expected_log)|
      assert_difference -> { AppGeneration::LogEntry.count }, 2 do # Expect both validation start and error logs
        error = assert_raises(CommandExecutionService::InvalidCommandError) do
          CommandExecutionService.new(@generated_app, @logger, cmd)
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
      assert_difference -> { AppGeneration::LogEntry.count }, 2 do
        assert_raises(Timeout::Error) { @service.execute }
      end

      log_entries = @generated_app.log_entries.order(created_at: :desc).limit(2)
      assert_equal "Created temporary directory", log_entries[0].message
      assert log_entries.all? { |entry| entry.info? }
    end
  end

  test "logs command output" do
    output = "Sample output"
    error = "Sample error"

    Open3.stub :popen3, mock_popen3(output, error, success: true) do
      assert_difference -> { AppGeneration::LogEntry.count }, 8 do
        @service.execute
      end

      log_entries = @generated_app.log_entries.order(created_at: :desc).limit(8)

      assert_equal "Rails app generation process finished successfully", log_entries[0].message
      assert_equal "Rails app generation process started", log_entries[1].message
      assert_equal "Initializing Rails application generation...\nSample output", log_entries[2].message
      assert_equal "Environment variables for command execution", log_entries[3].message
      assert_equal "System environment details", log_entries[4].message
      assert_equal "Preparing to execute command", log_entries[5].message
      assert_equal "Created temporary directory", log_entries[6].message

      buffer_entry = log_entries.find { |entry| entry.metadata["stream"] == "stdout" }
      assert_equal "Initializing Rails application generation...\nSample output", buffer_entry.message
    end
  end

  test "logs command errors" do
    output = ""
    error = "Error message"

    Open3.stub :popen3, mock_popen3(output, error, success: false) do
      assert_difference -> { AppGeneration::LogEntry.count }, 8 do
        assert_raises(RuntimeError) { @service.execute }
      end

      log_entries = @generated_app.log_entries.recent_first

      expected_messages = [
        "Command failed",
        "Initializing Rails application generation...",
        "Rails app generation process started",
        "Environment variables for command execution",
        "System environment details",
        "Preparing to execute command",
        "Created temporary directory",
        "Command validation successful",
        "Validating command: #{@command}"
      ]

      expected_messages.each do |message|
        assert log_entries.any? { |entry| entry.message.include?(message) }
      end

      error_log = log_entries.find { |entry| entry.message == "Command failed" }
      assert error_log.error?
      assert_equal "Initializing Rails application generation...", error_log.metadata["output"]
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
        assert_difference -> { AppGeneration::LogEntry.count }, 9 do
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

  test "handles cleanup when process doesn't exist" do
    output = "Sample output"
    error = "Sample error"
    pid = 12345

    Process.stub :kill, ->(*) { raise Errno::ESRCH } do
      Open3.stub :popen3, mock_popen3(output, error, success: true, pid: pid) do
        assert_nothing_raised do
          @service.execute
        end
      end
    end
  end

  test "executes valid template command" do
    template_command = "bin/rails app:template LOCATION=lib/templates/blog.rb"
    service = CommandExecutionService.new(@generated_app, @logger, template_command)
    output = "Template applied successfully"

    Open3.stub :popen3, mock_popen3(output, "", success: true) do
      assert_difference -> { @generated_app.log_entries.count }, 8 do
        service.execute
      end

      log_entries = @generated_app.log_entries.recent_first
      assert_equal "Rails app generation process finished successfully", log_entries.first.message
    end
  end

  test "validates template command format" do
    invalid_template_commands = {
      "bin/rails app:template" => "Invalid template command format",  # Missing LOCATION
      "bin/rails app:template LOCATION=" => "Invalid template command format",  # Empty LOCATION
      "bin/rails app:template LOCATION=;rm -rf /" => "Command contains invalid characters",  # Injection attempt
      "bin/rails app:template LOCATION=../../etc/passwd" => "Invalid template command format",  # Path traversal attempt
      "bin/rails app:template LOCATION=templates/bad.rb" => "Invalid template command format"  # Not in lib/templates
    }

    invalid_template_commands.each do |cmd, expected_error|
      assert_difference -> { AppGeneration::LogEntry.count }, 2 do
        error = assert_raises(CommandExecutionService::InvalidCommandError) do
          CommandExecutionService.new(@generated_app, @logger, cmd)
        end
        assert_equal expected_error, error.message

        log_entries = @generated_app.log_entries.order(created_at: :desc).limit(2)
        assert log_entries[0].error?
        assert_equal expected_error == "Command contains invalid characters" ?
          "Command injection attempt detected" :
          "Invalid template command format",
          log_entries[0].message
      end
    end
  end
end
