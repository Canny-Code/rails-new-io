require "open3"
require "timeout"
require "fileutils"

class CommandExecutionService
  ALLOWED_COMMANDS = [
    "rails new",
    "rails app:template",
    "bundle install",
    "rails db:create",
    "rails db:schema:dump",
    "rails db:migrate",
    "rails db:schema:dump:cache",
    "rails db:schema:dump:queue",
    "rails db:schema:dump:cable",
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
        # Options that can have a path value
        --(?:gemfile|path)(?:=|\s+)[\w\/\.-]+
        \s*
        |
        # Other common bundle install options
        --(?:
          jobs|retry|system|deployment|
          local|frozen|clean|standalone|full-index|
          conservative|force|prefer-local
        )
        (?:=\d+)?
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
      @logger.error(e.message, { command: @command })
      raise
    end

    @logger.debug("Command validation successful", { command: @command })
  end

  def setup_environment
    setup_work_directory
    @logger.debug("Directory setup complete", { work_dir: @work_dir })
  end

  def setup_work_directory
    @work_dir = if @command.start_with?("rails new")
      base_dir = "/var/lib/rails-new-io/workspaces"
      FileUtils.mkdir_p(base_dir)
      workspace_dir_name = "workspace-#{Time.current.to_i}-#{SecureRandom.hex(4)}"

      if Dir.exist?(workspace_dir_name)
        raise WhatTheFuckError, "Workspace directory #{workspace_dir_name} already exists?!"
      end

      File.join(base_dir, workspace_dir_name).tap do |dir|
        FileUtils.mkdir_p(dir)
        @generated_app.update(workspace_path: dir)
      end
    else
      File.join(@generated_app.workspace_path, @generated_app.name)
    end

    if !Dir.exist?(@work_dir)
      raise InvalidCommandError, "Work directory #{@work_dir} does not exist!"
    end
  end

  def run_isolated_process
    @logger.debug("Preparing to execute command", { command: @command, directory: @work_dir })
    log_system_environment_details

    env = {
      "RAILS_ENV" => "development",
      "NODE_ENV" => "development",
      "PATH" => ENV["PATH"],
      "HOME" => @work_dir,
      "BUNDLE_DEPLOYMENT" => "false",
      "BUNDLE_WITHOUT" => ""
    }

    if @command.start_with?("rails new")
      env.merge!({
        "BUNDLE_GEMFILE" => nil,
        "BUNDLE_USER_HOME" => nil,
        "BUNDLE_GEMFILE" => nil,
        "BUNDLE_PATH" => nil,
        "BUNDLE_APP_CONFIG" => nil,
        "BUNDLE_BIN" => nil
      })
    else
      env.merge!({
        "BUNDLE_GEMFILE" => File.join(@work_dir, "Gemfile"),
        "PATH" => "#{File.join(@work_dir, 'bin')}:#{env['PATH']}"
      })
    end

    bundle_command = if @command.start_with?("rails new")
      @command
    else
      @command.sub(/^rails/, "./bin/rails")
    end

    log_environment_variables_for_command_execution(env)

    buffer = Buffer.new(@generated_app, bundle_command)
    error_buffer = []

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
          error_buffer << line.strip
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
          output: output,
          error_buffer: error_buffer.join("<br>")
        })
        raise "Command failed with status: #{exit_status}"
      end

      if @command.start_with?("rails new")
        app_dir = File.join(@work_dir, @generated_app.name)

        # Set up bundle config for vendor/bundle
        Dir.chdir(app_dir) do
          [
            "bundle config set --local path vendor/bundle",
            "bundle config set --local disable_shared_gems true",
            "bundle config set --local deployment false",
            "bundle install",  # Reinstall gems to vendor/bundle
            "bundle config list > bundle_config.txt"  # Show the config for debugging
          ].each do |cmd|
            @logger.debug("Running post-rails-new command: #{cmd}")

            # Run in same process context
            out, err, status = Open3.capture3(env, cmd)

            unless status.success?
              @logger.error("Post-rails-new command failed", {
                command: cmd,
                output: out,
                error: err
              })
              raise "Post-rails-new command failed: #{cmd}"
            end

            buffer.append(out) unless out.empty?
            error_buffer << err unless err.empty?
          end
        end
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
