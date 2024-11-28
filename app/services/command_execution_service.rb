require "open3"
require "timeout"

class CommandExecutionService
  ALLOWED_COMMANDS = [ "rails new" ].freeze
  COMMAND_PATTERN = /\A
  rails\s+new\s+                    # Command start
  [a-zA-Z]                         # App name must start with a letter
  [a-zA-Z0-9_-]*\s+               # Rest of app name can have letters, numbers, underscores, hyphens
  (?!generate|destroy|server)       # Negative lookahead for other rails commands
  (?:
    (?:
      # Single character options with possible values
      -[rndGMOCATJBjc]\s+[\w\/.=-]+\s*|

      # Double-dash options with possible values
      --(?:
        (?:ruby|name|template|database|javascript|css)=[\w\/.=-]+|

        # Boolean options (with or without --no- or --skip- prefix)
        (?:(?:no-|skip-)?(?:
          namespace|collision-check|git|docker|keeps|action-mailer|action-mailbox|
          action-text|active-record|active-job|active-storage|action-cable|
          asset-pipeline|javascript|hotwire|jbuilder|test|system-test|bootsnap|
          dev-gems|thruster|rubocop|brakeman|ci|kamal|solid|dev|devcontainer|
          edge|main|api|minimal|bundle|decrypted-diffs|
          pretend|quiet|skip
        ))|

        # RC option with value
        rc=[\w\/.=-]+
      )
      \s*
    )*
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
    @generated_app.update(source_path: @temp_dir)
  end

  def run_isolated_process
    @logger.info("Executing command", { command: @command, directory: @temp_dir })
    log_environment_details

    env = {
      "BUNDLE_GEMFILE" => nil,
      "RAILS_ENV" => "development",
      "NODE_ENV" => "development",
      "PATH" => ENV["PATH"]
    }

    @logger.info("Environment variables for command execution", {
      env: env,
      command: @command,
      directory: @temp_dir
    })

    stdout_buffer = []
    stderr_buffer = []

    Open3.popen3(env, @command, chdir: @temp_dir) do |stdin, stdout, stderr, wait_thr|
      @pid = wait_thr&.pid
      @logger.info("Process started", { pid: @pid })

      stdout_thread = Thread.new do
        stdout.each_line do |line|
          stdout_buffer << line.strip
        end
      end

      stderr_thread = Thread.new do
        stderr.each_line do |line|
          stderr_buffer << line.strip
        end
      end

      stdout_thread.join
      stderr_thread.join

      exit_status = wait_thr&.value

      if exit_status&.success?
        @logger.info("Command completed successfully", {
          output: stdout_buffer.join("\n"),
          errors: stderr_buffer.join("\n")
        })
      else
        @logger.error("Command failed", {
          output: stdout_buffer.join("\n"),
          errors: stderr_buffer.join("\n"),
          status: exit_status
        })
        raise "Command failed with status: #{exit_status}"
      end

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
  end

  def log_environment_details
    @logger.info("System environment details", {
      ruby_version: RUBY_VERSION,
      ruby_platform: RUBY_PLATFORM,
      rails_version: Rails.version,
      pwd: Dir.pwd,
      path: ENV["PATH"],
      gem_path: ENV["GEM_PATH"],
      gem_home: ENV["GEM_HOME"],
      bundler_version: Bundler::VERSION
    })
  end
end
