require "open3"
require "timeout"
require "fileutils"

class CommandExecutionService
  ALLOWED_COMMANDS = [
    "rails new",
    "rails app:template",
    "bundle install",
    "bundle lock --add-platform x86_64-linux"
  ].freeze

  TEMPLATE_COMMAND_PATTERN = %r{\A
    rails\s+app:template\s+
    LOCATION=.+/template\.rb
  \z}x

  BUNDLE_INSTALL_PATTERN = /\A
    bundle\s+install    # Command start
    (?:
      \s+
      (?:
        # Common bundle install options
        --(?:
          jobs|retry|gemfile|system|deployment|
          local|frozen|clean|standalone|full-index|
          conservative|force|prefer-local
        )
        (?:=\d+)?
        \s*
        |
        # Path option with restricted values
        --path(?:=|\s+)(?!.*\.\.)[a-zA-Z0-9][a-zA-Z0-9_\/-]*
        \s*
      )*
    )?
  \z/x

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
    @work_dir = nil
    @pid = nil

    # Add --skip-bundle to rails new commands
    if @command.start_with?("rails new") && !@command.include?("--skip-bundle")
      @command = "#{@command} --skip-bundle"
    end
  end

  def execute
    validate_command!

    setup_environment

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
      when "bundle install"
        validate_bundle_install_command
      end
    rescue InvalidCommandError => e
      # If we get here, it means the command passed the initial check but failed format validation
      # Re-raise the error with the original message
      @logger.error(e.message, { command: @command })
      raise
    end

    @logger.debug("Command validation successful", { command: @command })
  end

  def setup_environment
    if @command.start_with?("rails new")
      @work_dir = if Rails.env.production?
        # Use persistent directory in production
        base_dir = "/var/lib/rails-new-io/workspaces"
        FileUtils.mkdir_p(base_dir)
        dir = File.join(base_dir, "workspace-#{Time.current.to_i}-#{SecureRandom.hex(4)}")
        FileUtils.mkdir_p(dir)
        dir
      else
        Dir.mktmpdir
      end

      @logger.debug("Created workspace directory", { path: @work_dir })
      @generated_app.update(workspace_path: @work_dir)
    else
      @work_dir = File.join(@generated_app.workspace_path, @generated_app.name)
      @logger.debug("Using existing app directory", { path: @work_dir })
    end

    puts "DEBUG: Command type: #{@command.split.first(2).join(' ')}"
    puts "DEBUG: Work directory: #{@work_dir}"
    puts "DEBUG: Directory exists? #{Dir.exist?(@work_dir)}"
    puts "DEBUG: Generated app workspace path: #{@generated_app.workspace_path}"
    puts "DEBUG: Generated app name: #{@generated_app.name}"

    if !@command.start_with?("rails new") && !Dir.exist?(@work_dir)
      puts "DEBUG: ERROR - Work directory does not exist for non-rails-new command!"
      raise InvalidCommandError, "Work directory #{@work_dir} does not exist"
    end
  end

  def run_isolated_process
    @logger.debug("Preparing to execute command", { command: @command, directory: @work_dir })
    log_system_environment_details

    env = {
      "RAILS_ENV" => Rails.env,
      "NODE_ENV" => Rails.env,
      "PATH" => ENV["PATH"],
      "HOME" => @work_dir,
      "BUNDLE_DEPLOYMENT" => nil  # Unset deployment mode for app generation
    }

    puts "\nDEBUG: ====== Command Execution Setup ======"
    puts "DEBUG: Command: #{@command}"
    puts "DEBUG: Work directory: #{@work_dir}"

    # Create .bundle directory and config if needed
    unless @command.start_with?("rails new")
      bundle_dir = File.join(@work_dir, ".bundle")
      FileUtils.mkdir_p(bundle_dir)
      config_path = File.join(bundle_dir, "config")

      # Ensure .bundle/config exists and is a file
      if File.directory?(config_path)
        FileUtils.rm_rf(config_path)
      end
      File.write(config_path, "") unless File.exist?(config_path)

      # Set explicit bundle config path
      env["BUNDLE_APP_CONFIG"] = bundle_dir
      puts "DEBUG: Created bundle config at #{config_path}"
    end

    puts "DEBUG: Directory contents:"
    puts `ls -la #{@work_dir}`.lines.map { |l| "DEBUG: #{l.strip}" }

    if @command.start_with?("rails new")
      env.merge!({
        "BUNDLE_GEMFILE" => nil,
        "BUNDLE_PATH" => nil,
        "BUNDLE_APP_CONFIG" => nil,
        "BUNDLE_BIN" => nil,
        "BUNDLE_USER_HOME" => nil
      })
      puts "DEBUG: Rails new command - cleared bundle env vars"
    else
      gemfile_path = File.join(@work_dir, "Gemfile")
      env.merge!({
        "BUNDLE_GEMFILE" => gemfile_path,
        "BUNDLE_JOBS" => "4",
        "BUNDLE_RETRY" => "3",
        "PATH" => "#{File.join(@work_dir, 'bin')}:#{ENV['PATH']}"
      })
      puts "\nDEBUG: ====== Bundle Environment ======"
      puts "DEBUG: BUNDLE_GEMFILE=#{env['BUNDLE_GEMFILE']}"
      puts "DEBUG: Gemfile exists? #{File.exist?(gemfile_path)}"
      if File.exist?(gemfile_path)
        puts "DEBUG: Gemfile contents:"
        puts File.read(gemfile_path).lines.map { |l| "DEBUG: #{l.strip}" }
      end
      puts "DEBUG: bin directory exists? #{Dir.exist?(File.join(@work_dir, 'bin'))}"
    end

    bundle_command = @command.include?("app:template") ? @command.sub("rails", "./bin/rails") : @command
    puts "\nDEBUG: ====== Final Execution ======"
    puts "DEBUG: Final command: #{bundle_command}"
    puts "DEBUG: In directory: #{@work_dir}"

    log_environment_variables_for_command_execution(env)

    buffer = Buffer.new(@generated_app, bundle_command)

    @logger.debug("Command execution started: #{@command}", {
      pid: @pid,
      command: @command,
      directory: @work_dir
    })

    Open3.popen3(env, bundle_command, chdir: @work_dir) do |stdin, stdout, stderr, wait_thr|
      @pid = wait_thr&.pid

      stdout_thread = Thread.new do
        stdout.each_line do |line|
          buffer.append(line.strip)
        end
      end

      stderr_thread = Thread.new do
        stderr.each_line do |line|
          puts "DEBUG: STDERR: #{line.strip}"
        end
      end

      stdout_thread.join
      stderr_thread.join
      buffer.complete!

      exit_status = wait_thr&.value
      output = buffer.message || "No output"

      unless exit_status&.success?
        @logger.error("Command failed", {
          status: exit_status,
          output: output
        })
        raise "Command failed with status: #{exit_status}"
      end

      @work_dir
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

  def validate_bundle_install_command
    unless @command.match?(BUNDLE_INSTALL_PATTERN)
      @logger.error("Invalid bundle install command format", { command: @command })
      raise InvalidCommandError, "Invalid bundle install command format"
    end
  end
end
