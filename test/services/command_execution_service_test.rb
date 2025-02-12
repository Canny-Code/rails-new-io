require "test_helper"
require "ostruct"

class CommandExecutionServiceTest < ActiveSupport::TestCase
  def setup
    @user = users(:john)
    @recipe = recipes(:blog_recipe)
    @work_dir = Dir.mktmpdir

    @logger = mock("logger")
    @logger.stubs(:info).with { |message, metadata = {}| @generated_app.log_entries.create!(message: message, metadata: metadata, level: :info, phase: :generating_rails_app) }
    @logger.stubs(:error).with { |message, metadata = {}| @generated_app.log_entries.create!(message: message, metadata: metadata, level: :error, phase: :generating_rails_app) }
    @logger.stubs(:debug).with { |message, metadata = {}| @generated_app.log_entries.create!(message: message, metadata: metadata, level: :debug, phase: :generating_rails_app) }
    AppGeneration::Logger.stubs(:new).returns(@logger)

    # Use an existing app and reset its status
    @generated_app = generated_apps(:pending_app)
    @generated_app.update!(workspace_path: @work_dir)
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
    FileUtils.rm_rf(@work_dir) if @work_dir && Dir.exist?(@work_dir)
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

      Open3.stub :popen3, mock_popen3(output, error, success: true) do
        assert_difference -> { @generated_app.log_entries.count }, 8 do
          service.execute
        end

        log_entries = @generated_app.log_entries.order(created_at: :asc).offset(initial_count)

        buffer_entry = log_entries.find { |entry| entry.metadata["stream"] == "stdout" }
        assert_equal "Executing command: `#{command} --skip-bundle`\nSample output", buffer_entry.message
        assert log_entries.all? { it.info? || it.debug? }

        @generated_app.log_entries.where("id > ?", @generated_app.log_entries.limit(initial_count).pluck(:id).last).destroy_all
      end
    end
  end

  test "validates app name matches GeneratedApp name" do
    wrong_name = "wrong-app-name"
    invalid_command = "rails new #{wrong_name} -d postgres --skip-bundle"

    assert_difference -> { AppGeneration::LogEntry.count }, 3 do # Expect validation start, format validation success, and error logs
      error = assert_raises(CommandExecutionService::InvalidCommandError) do
        CommandExecutionService.new(@generated_app, @logger, invalid_command).execute
      end
      assert_equal "App name in command must match GeneratedApp name", error.message
    end

    log_entries = @generated_app.log_entries.order(created_at: :asc).last(3)

    assert log_entries[0].debug?
    assert_match /Validating command/, log_entries[0].message

    assert log_entries[1].error?
    assert_equal "Invalid app name", log_entries[1].message

    assert log_entries[2].error?
    assert_equal "App name in command must match GeneratedApp name", log_entries[2].message
    assert_equal({ "command" => invalid_command }, log_entries[2].metadata)
  end

  test "raises error for invalid commands" do
    assert_difference -> { AppGeneration::LogEntry.count }, 2 do # Expect validation start and error message
      error = assert_raises(CommandExecutionService::InvalidCommandError) do
        CommandExecutionService.new(@generated_app, @logger, "rm -rf /").execute
      end
      assert_equal "Command must start with one of: rails new, rails app:template, bundle install", error.message
    end

    log_entries = @generated_app.log_entries.order(created_at: :asc).last(2)
    assert log_entries[0].debug?
    assert_match /Validating command/, log_entries[0].message

    assert log_entries[1].error?
    assert_equal "Command must start with one of: rails new, rails app:template, bundle install", log_entries[1].message
    assert_equal({ "command" => "rm -rf /" }, log_entries[1].metadata)
  end

  test "validates rails new command format" do
    command = "rails new --invalid-flag --skip-bundle"

    assert_difference -> { AppGeneration::LogEntry.count }, 3 do
      error = assert_raises(CommandExecutionService::InvalidCommandError) do
        CommandExecutionService.new(@generated_app, @logger, command).execute
      end
      assert_equal "Invalid rails new command format", error.message
    end

    log_entries = @generated_app.log_entries.order(created_at: :asc).last(3)
    assert log_entries[0].debug?
    assert_match /Validating command/, log_entries[0].message
    assert log_entries[1].error?
    assert_equal "Invalid rails new command format", log_entries[1].message
    assert_equal({ "command" => command }, log_entries[1].metadata)
    assert log_entries[2].error?
    assert_equal "Invalid rails new command format", log_entries[2].message
    assert_equal({ "command" => command }, log_entries[2].metadata)
  end

  test "detects command injection attempts" do
    command = "rails new; rm -rf / --skip-bundle"

    assert_difference -> { AppGeneration::LogEntry.count }, 2 do
      error = assert_raises(CommandExecutionService::InvalidCommandError) do
        CommandExecutionService.new(@generated_app, @logger, command).execute
      end
      assert_equal "Command injection attempt detected", error.message
    end

    log_entries = @generated_app.log_entries.order(created_at: :asc).last(2)
    assert log_entries[0].debug?
    assert_match /Validating command/, log_entries[0].message
    assert log_entries[1].error?
    assert_equal "Command injection attempt detected", log_entries[1].message
    assert_equal({ "command" => command }, log_entries[1].metadata)
  end

  test "rejects rails generate commands" do
    command = "rails generate model User"

    assert_difference -> { AppGeneration::LogEntry.count }, 2 do
      error = assert_raises(CommandExecutionService::InvalidCommandError) do
        CommandExecutionService.new(@generated_app, @logger, command).execute
      end
      assert_equal "Command must start with one of: rails new, rails app:template, bundle install", error.message
    end

    log_entries = @generated_app.log_entries.order(created_at: :asc).last(2)
    assert log_entries[0].debug?
    assert_match /Validating command/, log_entries[0].message
    assert log_entries[1].error?
    assert_equal "Command must start with one of: rails new, rails app:template, bundle install", log_entries[1].message
    assert_equal({ "command" => command }, log_entries[1].metadata)
  end

  test "handles timeouts" do
    @service.stub :run_isolated_process, -> { raise Timeout::Error } do
      assert_difference -> { AppGeneration::LogEntry.count }, 3 do
        assert_raises(Timeout::Error) { @service.execute }
      end

      log_entries = @generated_app.log_entries.order(created_at: :desc).limit(1)

      assert_equal "Created workspace directory", log_entries[0].message
      assert log_entries.all? { it.info? || it.debug? }
    end
  end

  test "logs command output" do
    output = "Sample output"
    error = "Sample error"

    Open3.stub :popen3, mock_popen3(output, error, success: true) do
      assert_difference -> { AppGeneration::LogEntry.count }, 8 do
        @service.execute
      end

      log_entries = @generated_app.log_entries.recent_first

      expected_messages = [
        "Validating command: #{@valid_commands.first} --skip-bundle",
        "Command validation successful",
        "Created workspace directory",
        "Preparing to execute command",
        "System environment details",
        "Environment variables for command execution"
      ]

      expected_messages.each do |message|
        assert log_entries.any? { |entry| entry.message == message },
          "Expected to find log entry with message '#{message}'"
      end

      buffer_entry = log_entries.find { |entry| entry.metadata["stream"] == "stdout" }
      assert_equal "Executing command: `#{@valid_commands.first} --skip-bundle`\nSample output", buffer_entry.message
      assert log_entries.all? { it.info? || it.debug? }
    end
  end

  test "logs command errors" do
    output = ""
    error = "Error message"

    Open3.stub :popen3, mock_popen3(output, error, success: false) do
      assert_difference -> { AppGeneration::LogEntry.count }, 9 do
        assert_raises(RuntimeError) { @service.execute }
      end

      log_entries = @generated_app.log_entries.recent_first

      expected_messages = [
        "Command failed",
        "Command execution started",
        "Environment variables for command execution",
        "System environment details",
        "Preparing to execute command",
        "Created workspace directory",
        "Command validation successful",
        "Validating command: #{@valid_commands.first}"
      ]

      expected_messages.each do |message|
        assert log_entries.any? { |entry| entry.message.include?(message) },
          "Expected to find log entry containing '#{message}'"
      end

      error_log = log_entries.find { |entry| entry.message == "Command failed" }
      assert error_log.error?

      assert_equal "Executing command: `#{@valid_commands.first} --skip-bundle`", error_log.metadata["output"]
      assert error_log.metadata["status"]

      log_entries.each do |entry|
        assert [ :info, :error, :debug ].include?(entry.level.to_sym),
          "Expected log level to be info, error, or debug but was #{entry.level}"
      end
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
          "Command execution started",
          "Environment variables for command execution",
          "System environment details",
          "Preparing to execute command",
          "Created workspace directory",
          "Command validation successful",
          "Validating command: #{@valid_commands.first}"
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
    template_command = "rails app:template LOCATION=lib/templates/template.rb"
    service = CommandExecutionService.new(@generated_app, @logger, template_command)
    output = "Template applied successfully"

    Open3.stub :popen3, mock_popen3(output, "", success: true) do
      assert_difference -> { @generated_app.log_entries.count }, 8 do
        service.execute
      end

      log_entries = @generated_app.log_entries.recent_first
      assert_equal "Command execution started: rails app:template LOCATION=lib/templates/template.rb", log_entries.first.message
    end
  end

  test "validates template command requires LOCATION" do
    command = "rails app:template"

    assert_difference -> { AppGeneration::LogEntry.count }, 3 do
      error = assert_raises(CommandExecutionService::InvalidCommandError) do
        CommandExecutionService.new(@generated_app, @logger, command).execute
      end
      assert_equal "Invalid template command format", error.message
    end

    log_entries = @generated_app.log_entries.order(created_at: :asc).last(3)
    assert log_entries[0].debug?
    assert_match /Validating command/, log_entries[0].message
    assert log_entries[1].error?
    assert_equal "Invalid template command format", log_entries[1].message
    assert_equal({ "command" => command }, log_entries[1].metadata)
    assert log_entries[2].error?
    assert_equal "Invalid template command format", log_entries[2].message
    assert_equal({ "command" => command }, log_entries[2].metadata)
  end

  test "detects template command injection attempts" do
    command = "rails app:template LOCATION=;rm -rf /"

    assert_difference -> { AppGeneration::LogEntry.count }, 2 do
      error = assert_raises(CommandExecutionService::InvalidCommandError) do
        CommandExecutionService.new(@generated_app, @logger, command).execute
      end
      assert_equal "Command injection attempt detected", error.message
    end

    log_entries = @generated_app.log_entries.order(created_at: :asc).last(2)
    assert log_entries[0].debug?
    assert_match /Validating command/, log_entries[0].message
    assert log_entries[1].error?
    assert_equal "Command injection attempt detected", log_entries[1].message
    assert_equal({ "command" => command }, log_entries[1].metadata)
  end

  test "rejects template path traversal attempts" do
    command = "rails app:template LOCATION=../../etc/passwd"

    assert_difference -> { AppGeneration::LogEntry.count }, 3 do
      error = assert_raises(CommandExecutionService::InvalidCommandError) do
        CommandExecutionService.new(@generated_app, @logger, command).execute
      end
      assert_equal "Invalid template command format", error.message
    end

    log_entries = @generated_app.log_entries.order(created_at: :asc).last(3)
    assert log_entries[0].debug?
    assert_match /Validating command/, log_entries[0].message
    assert log_entries[1].error?
    assert_equal "Invalid template command format", log_entries[1].message
    assert_equal({ "command" => command }, log_entries[1].metadata)
    assert log_entries[2].error?
    assert_equal "Invalid template command format", log_entries[2].message
    assert_equal({ "command" => command }, log_entries[2].metadata)
  end

  test "validates bundle install command format" do
    invalid_bundle_commands = {
      "bundle" => "Command must start with one of: rails new, rails app:template, bundle install",
      "bundle install --invalid-flag" => "Invalid bundle install command format",  # Invalid flag
      "bundle install;rm -rf /" => "Command injection attempt detected",  # Injection attempt
      "bundle install --path=../etc" => "Invalid bundle install command format",  # Path traversal attempt
      "bundle exec install" => "Command must start with one of: rails new, rails app:template, bundle install"
    }

    invalid_bundle_commands.each do |cmd, expected_error|
      expected_count = cmd.start_with?("bundle install") && !cmd.match?(/[;&|]/) ? 3 : 2
      assert_difference -> { AppGeneration::LogEntry.count }, expected_count do
        error = assert_raises(CommandExecutionService::InvalidCommandError) do
          CommandExecutionService.new(@generated_app, @logger, cmd).execute
        end
        assert_equal expected_error, error.message

        log_entries = @generated_app.log_entries.order(created_at: :desc).limit(expected_count)
        assert log_entries[0].error?
        assert_equal expected_error, log_entries[0].message
      end
    end

    # Test valid bundle install commands
    valid_commands = [
      "bundle install",
      "bundle install --jobs=4",
      "bundle install --retry=3",
      "bundle install --path vendor/bundle",
      "bundle install --deployment --jobs=4 --retry=3",
      "bundle install --local --frozen"
    ]

    valid_commands.each do |cmd|
      assert_nothing_raised do
        CommandExecutionService.new(@generated_app, @logger, cmd)
      end
    end
  end
end
