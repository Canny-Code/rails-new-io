require "open3"
require "timeout"

class CommandExecutionService
  ALLOWED_COMMANDS = [
    "rails new",
    "rails app:template"
  ].freeze

  TEMPLATE_COMMAND_PATTERN = %r{\A
    rails\s+app:template\s+
    LOCATION=.+/template\.rb
  \z}x

  COMMAND_PATTERN = /\A
  rails\s+new\s+                    # Command start
  [a-zA-Z]                         # App name must start with a letter
  [a-zA-Z0-9_-]*                  # Rest of app name can have letters, numbers, underscores, hyphens
  (?!generate|destroy|server)       # Negative lookahead for other rails commands
  (?:
    \s+
    (?:
      # Single character options with possible values
      -[rndGMOCATJBjc]\s+[\w\/.=-]+\s*|

      # Double-dash options with possible values
      --(?:
        (?:ruby|name|template|database|javascript|css|asset-pipeline)=[\w\/.=-]+|

        # Boolean options (with or without --no- or --skip- prefix)
        (?:(?:no-|skip-)?(?:
          namespace|collision-check|git|docker|keeps|action-mailer|action-mailbox|
          action-text|active-record|active-job|active-storage|action-cable|
          asset-pipeline|javascript|hotwire|jbuilder|test|system-test|bootsnap|
          dev-gems|thruster|rubocop|brakeman|ci|kamal|solid|dev|devcontainer|
          edge|main|api|minimal|bundle|decrypted-diffs|spring|
          pretend|quiet|skip
        ))|

        # RC option with value
        rc=[\w\/.=-]+
      )
      \s*
    )*
  )?
  \z/x

  VALID_OPTIONS = /\A--?[a-z][\w-]*\z/  # Must start with letter after dash(es)
  MAX_TIMEOUT = 300 # 5 minutes

  class InvalidCommandError < StandardError
    attr_reader :metadata

    def initialize(message, metadata = {})
      super(message)
      @metadata = metadata
    end
  end

  def initialize(generated_app, logger, command = nil)
    @generated_app = generated_app
    @logger = logger
    @command = command&.to_s&.strip || generated_app.command
    @temp_dir = nil
    @pid = nil
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

    command_type = ALLOWED_COMMANDS.find { |cmd| @command.start_with?(cmd) }
    unless command_type
      @logger.error("Invalid command prefix", { command: @command })
      raise InvalidCommandError, "Command must start with one of: #{ALLOWED_COMMANDS.join(', ')}"
    end

    # Check for command injection attempts
    if @command.match?(/[;&|]/)
      @logger.error("Command injection attempt detected", { command: @command })
      raise InvalidCommandError, "Command contains invalid characters"
    end

    # Validate based on command type
    case command_type
    when "rails new"
      validate_rails_new_command
    when "rails app:template"
      validate_template_command
    end

    @logger.info("Command validation successful", { command: @command })
  end

  def setup_environment
    if @command.start_with?("rails new")
      @temp_dir = Dir.mktmpdir
      @logger.info("Created temporary directory", { path: @temp_dir })
      @generated_app.update(workspace_path: @temp_dir)
    else
      generated_app_directory = File.join(@generated_app.workspace_path, @generated_app.name)
      @logger.info("Using existing app directory", { path: generated_app_directory })
    end
  end

  def run_isolated_process
    @logger.info("Preparing to execute command", { command: @command, directory: @temp_dir })
    log_system_environment_details

    env = {
      "BUNDLE_GEMFILE" => nil,
      "BUNDLE_PATH" => File.join(@temp_dir, "vendor/bundle"),
      "BUNDLE_APP_CONFIG" => File.join(@temp_dir, ".bundle"),
      "RAILS_ENV" => "development",
      "NODE_ENV" => "development",
      "PATH" => ENV["PATH"]
    }

    log_environment_variables_for_command_execution(env)

    buffer = Buffer.new(@generated_app)

    Open3.popen3(env, @command, chdir: @temp_dir) do |stdin, stdout, stderr, wait_thr|
      @pid = wait_thr&.pid
      @logger.info("Rails app generation process started", { pid: @pid })

      stdout_thread = Thread.new do
        stdout.each_line do |line|
          buffer.append(line.strip)
        end
      end

      stdout_thread.join

      buffer.complete!
      exit_status = wait_thr&.value
      output = buffer.message || "No output"

      unless exit_status&.success?
        @logger.error("Command failed", {
          status: exit_status,
          output: output
        })
        raise "Rails app generation failed with status: #{exit_status}"
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

  def log_system_environment_details
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

  def log_environment_variables_for_command_execution(env)
    @logger.info("Environment variables for command execution", {
      command: @command,
      directory: @temp_dir,
      env: env
    })
  end

  def validate_rails_new_command
    unless @command.match?(COMMAND_PATTERN)
      @logger.error("Invalid rails new command format", { command: @command })
      raise InvalidCommandError, "Invalid rails new command format"
    end

    app_name = @command.split[2]
    unless app_name == @generated_app.name
      @logger.error("Invalid app name", {
        command: @command,
        expected: @generated_app.name,
        actual: app_name
      })
      raise InvalidCommandError, "App name in command must match GeneratedApp name"
    end
  end

  def validate_template_command
    unless @command.match?(TEMPLATE_COMMAND_PATTERN)
      metadata = { command: @command }
      @logger.error("Invalid template command format", metadata)
      raise InvalidCommandError.new("Invalid template command format", metadata)
    end
  end
end
