require "open3"
require "timeout"

class CommandExecutionService
  ALLOWED_COMMANDS = [ "rails new" ].freeze
  COMMAND_PATTERN = /\A
    rails\s+new\s+                    # Command start
    [\w-]+\s+                         # App name (required)
    (?!generate|destroy|server)       # Negative lookahead for other rails commands
    (?:
      (?:--?[\w-]+(?:\s+[\w-]+)?     # Options with or without values
      \s*)*                          # Multiple options allowed
    )
  \z/x
  VALID_OPTIONS = /\A--?[a-z][\w-]*\z/  # Must start with letter after dash(es)
  MAX_TIMEOUT = 300 # 5 minutes

  class InvalidCommandError < StandardError; end

  def initialize(generated_app, command)
    @generated_app = generated_app
    @command = command.to_s.strip
    @temp_dir = nil
    @pid = nil
    @logger = AppGeneration::Logger.new(generated_app)
    validate_command!
  end

  def execute
    setup_environment

    Timeout.timeout(MAX_TIMEOUT) do
      run_isolated_process
    end
  ensure
    cleanup
  end

  private

  def validate_command!
    @logger.info("Validating command: #{@command}")

    unless @command.start_with?(*ALLOWED_COMMANDS)
      @logger.error("Invalid command prefix", { command: @command })
      raise InvalidCommandError, "Command must start with 'rails new'"
    end

    # Check for command injection attempts
    if @command.match?(/[;&|]/)
      @logger.error("Command injection attempt detected", { command: @command })
      raise InvalidCommandError, "Command contains invalid characters"
    end

    # Validate overall command structure
    unless @command.match?(COMMAND_PATTERN)
      @logger.error("Invalid command format", { command: @command })
      raise InvalidCommandError, "Invalid command format"
    end

    # Extract and validate app name
    app_name = @command.split[2] # rails[0] new[1] app_name[2] ...
    unless app_name == @generated_app.name
      @logger.error("Invalid app name", {
        command: @command,
        expected: @generated_app.name,
        actual: app_name
      })
      raise InvalidCommandError, "App name in command must match GeneratedApp name"
    end

    @logger.info("Command validation successful", { command: @command })
  end

  def setup_environment
    @temp_dir = Dir.mktmpdir
    @logger.info("Created temporary directory", { path: @temp_dir })
  end

  def run_isolated_process
    @logger.info("Executing command", { command: @command, directory: @temp_dir })

    Open3.popen3(@command, chdir: @temp_dir) do |stdin, stdout, stderr, wait_thr|
      @pid = wait_thr&.pid
      @logger.info("Process started", { pid: @pid })

      stdout_thread = Thread.new do
        stdout.each_line do |line|
          @logger.info("Command output", { output: line.strip })
        end
      end

      stderr_thread = Thread.new do
        stderr.each_line do |line|
          @logger.error("Command error", { error: line.strip })
        end
      end

      stdout_thread.join
      stderr_thread.join

      exit_status = wait_thr&.value
      raise "Command failed with status: #{exit_status}" unless exit_status&.success?

      @temp_dir
    end
  end

  def cleanup
    if @pid
      begin
        Process.kill(0, @pid)  # Check if process exists
        Process.kill("TERM", @pid)
        @logger.info("Terminated process", { pid: @pid })
      rescue Errno::ESRCH
        # Process doesn't exist anymore, which is fine
      end
    end

    if @temp_dir && Dir.exist?(@temp_dir)
      FileUtils.remove_entry_secure(@temp_dir)
      @logger.info("Cleaned up temporary directory", { path: @temp_dir })
    end
  end
end
