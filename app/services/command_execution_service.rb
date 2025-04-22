require "open3"
require "timeout"
require "fileutils"
require "pathname"

class CommandExecutionService
  RAILS_GEN_ROOT = "/var/lib/rails-new-io/rails-env".freeze
  WORKSPACES_ROOT = "/var/lib/rails-new-io/workspaces".freeze
  RUBY_VERSION = "3.4.1".freeze
  RAILS_VERSION = "8.0.1".freeze
  BUNDLER_VERSION = "2.6.3".freeze

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

  ALLOWED_PATHS = [
    RAILS_GEN_ROOT,
    WORKSPACES_ROOT,
    "/var/lib/rails-new-io/home",
    "/var/lib/rails-new-io/config",
    "/var/lib/rails-new-io/cache",
    "/var/lib/rails-new-io/data"
  ].map { |path| Pathname.new(path).freeze }.freeze

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
    @work_dir = nil
    @pid = nil
  end

  def execute
    validate_command!
    validate_work_directory! if @work_dir  # Check existing work_dir if set
    setup_work_directory
    validate_work_directory!  # Validate again after setup

    Timeout.timeout(MAX_TIMEOUT) do
      run_isolated_process
    end
  ensure
    cleanup
  end

  private

  def validate_command!
    @logger.debug("Validating command: #{@command}")

    command_type = ALLOWED_COMMANDS.find do |cmd|
      @command.start_with?(cmd)
    end
    unless command_type
      @logger.error("Command must start with one of: #{ALLOWED_COMMANDS.join(', ')}", { command: @command })
      raise InvalidCommandError, "Command must start with one of: #{ALLOWED_COMMANDS.join(', ')}"
    end

    # Check for command injection attempts
    if @command.match?(/[;&|]/)
      @logger.error("Command injection attempt detected", { command: @command })
      raise InvalidCommandError, "Command injection attempt detected"
    end

    begin
      # Validate based on command type
      case command_type
      when "rails new"
        validate_rails_new_command
      when "rails app:template"
        validate_template_command
      end
    rescue InvalidCommandError => e
      @logger.error(e.message, { command: @command })
      raise
    end

    @logger.debug("Command validation successful", { command: @command })
  end

  def validate_work_directory!
    raise InvalidCommandError, "Work directory not set up" unless @work_dir
    work_dir_path = Pathname.new(@work_dir)

    # Allow test directories (those under /tmp or /var/folders) in test environment
    return if Rails.env.test? && (work_dir_path.to_s.start_with?("/tmp/") || work_dir_path.to_s.start_with?("/var/folders/"))

    # Ensure the work directory is under an allowed path
    unless ALLOWED_PATHS.any? { |allowed| work_dir_path.to_s.start_with?(allowed.to_s) }
      @logger.error("Invalid work directory path", { work_dir: @work_dir })
      raise InvalidCommandError, "Invalid work directory path"
    end

    raise InvalidCommandError, "Work directory does not exist" unless Dir.exist?(@work_dir)
  end

  def setup_work_directory
    base_dir = Pathname.new(WORKSPACES_ROOT)

    @work_dir = if @command.start_with?("rails new")
      FileUtils.mkdir_p(base_dir)

      timestamp = Time.current.to_i.to_s
      random_hex = SecureRandom.hex(4)
      workspace_dir_name = [ "workspace", timestamp, random_hex ].join("-")

      dir = base_dir.join(workspace_dir_name)
      FileUtils.mkdir_p(dir)
      @generated_app.update(workspace_path: dir.to_s)
      @logger.info("Created workspace directory", { workspace_path: dir.to_s })
      dir.to_s
    else
      dir = Pathname.new(@generated_app.workspace_path).join(@generated_app.name)
      @logger.info("Using existing workspace directory", { workspace_path: dir.to_s })
      dir.to_s
    end
  end

  def run_isolated_process
    @logger.debug("Preparing to execute command", { command: @command, directory: @work_dir })
    log_system_environment_details

    env = env_for_command
    log_environment_variables_for_command_execution(env)

    buffer = Buffer.new(@generated_app, @command)
    error_buffer = []

    rails_cmd = "#{RAILS_GEN_ROOT}/gems/bin/rails"

    command_args = if @command.start_with?("rails new")
      [ "new", *@command.split[2..-1] ]
    else
      # For other rails commands (like app:template), don't include 'rails' in the args
      @command.split[1..-1]
    end

    # Validate work directory one final time before execution
    validate_work_directory!
    options = { unsetenv_others: true, chdir: @work_dir }

    Bundler.with_unbundled_env do
      execute_command(env, [ rails_cmd, *command_args ], buffer, error_buffer, options)
    end

    @work_dir
  end

  def env_for_command
    base_env = {
      "RAILS_ENV" => "development",
      "NODE_ENV" => "development",
      "GEM_HOME" => "#{RAILS_GEN_ROOT}/gems",
      "GEM_PATH" => "#{RAILS_GEN_ROOT}/gems:#{RAILS_GEN_ROOT}/ruby/lib/ruby/gems/3.4.0",
      "PATH" => "#{RAILS_GEN_ROOT}/gems/bin:#{RAILS_GEN_ROOT}/ruby/bin:#{RAILS_GEN_ROOT}/node/bin:/usr/local/bin:/usr/bin:/bin:/opt/homebrew/bin",
      "HOME" => "/var/lib/rails-new-io/home",
      "RAILS_DEBUG_TEMPLATE" => "1",
      # Node.js environment for new Rails apps
      "npm_config_prefix" => "#{RAILS_GEN_ROOT}/node",
      "NODE_PATH" => "#{RAILS_GEN_ROOT}/node_modules",
      "COREPACK_HOME" => "#{RAILS_GEN_ROOT}/.corepack",
      "BUNDLE_WITHOUT" => "",
      "BUNDLE_WITH" => "development:test"
    }

    if RUBY_PLATFORM.include?("darwin")
      # OS X specific environment variables
      openssl_dir = "/opt/homebrew/opt/openssl@3"
      base_env.merge!({
        "LDFLAGS" => "-L#{openssl_dir}/lib",
        "CPPFLAGS" => "-I#{openssl_dir}/include",
        "PKG_CONFIG_PATH" => "#{openssl_dir}/lib/pkgconfig",
        "CONFIGURE_ARGS" => "--with-openssl-dir=#{openssl_dir}"
      })
    end

    base_env
  end

  def execute_command(env, command_with_args, buffer, error_buffer, options)
    Open3.popen3(env, *command_with_args, options) do |stdin, stdout, stderr, wait_thr|
      @pid = wait_thr&.pid

      stdout_thread = Thread.new do
        stdout.each_line do |line|
          buffer.append(line.strip)
        end
      end

      stderr_thread = Thread.new do
        stderr.each_line do |line|
          next if line.strip.match?(/^.*warning: .*$/)
          next if line.strip.blank?
          error_buffer << line.strip
        end
        @logger.debug("Command stderr:<br>#{error_buffer.join("<br>")}")
      end

      stdout_thread.join
      stderr_thread.join
      buffer.complete!

      exit_status = wait_thr&.value

      if !exit_status&.success? || error_buffer.any? { |line| line.include?("aborted!") }
        @logger.error("Command failed", {
          status: exit_status,
          stack_trace: error_buffer.join("<br>"),
          command: command_with_args.join(" "),
          directory: @work_dir,
          env: env
        })
        raise "Command failed with status: #{exit_status}"
      end
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
    @logger.debug("System environment details", {
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
    @logger.debug("Environment variables for command execution", {
      command: @command,
      directory: @work_dir,
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
