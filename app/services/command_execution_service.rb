require "open3"
require "timeout"
require "fileutils"

class CommandExecutionService
  RAILS_GEN_ROOT = "/var/lib/rails-new-io/rails-env".freeze
  RUBY_VERSION = "3.4.1".freeze
  RAILS_VERSION = "8.0.1".freeze
  BUNDLER_VERSION = "2.6.3".freeze

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

  def ruby_platform
    @ruby_platform ||= begin
      platform_cmd = "#{RAILS_GEN_ROOT}/ruby/bin/ruby -e 'puts RUBY_PLATFORM'"
      platform = `#{platform_cmd}`.strip

      if platform.blank?
        # Fallback in case the command fails
        case RbConfig::CONFIG["host_os"]
        when /darwin/
          "arm64-darwin24"
        else
          "x86_64-linux"
        end
      else
        platform
      end
    end
  end

  def platform_path
    @platform_path ||= "#{RAILS_GEN_ROOT}/ruby/lib/ruby/3.4.0/#{ruby_platform}"
  end

  def ruby_lib_paths
    [
      "#{RAILS_GEN_ROOT}/ruby/lib/ruby/3.4.0",
      platform_path
    ].join(":")
  end

  def run_isolated_process
    @logger.debug("Preparing to execute command", { command: @command, directory: @work_dir })

    log_system_environment_details

    ruby_dir = "#{RAILS_GEN_ROOT}/ruby"
    base_env = {
      "RAILS_ENV" => "development",
      "NODE_ENV" => "development",
      # Bundler
      "BUNDLE_GEMFILE" => nil,
      "BUNDLE_BIN" => nil,
      "BUNDLE_PATH" => nil,
      "BUNDLE_USER_HOME" => "#{RAILS_GEN_ROOT}/bundle",
      "BUNDLE_APP_CONFIG" => nil,
      "BUNDLE_DISABLE_SHARED_GEMS" => nil,
      # Ruby
      "GEM_HOME" => "#{RAILS_GEN_ROOT}/gems",
      "GEM_PATH" => "#{RAILS_GEN_ROOT}/gems",
      "RUBYOPT" => "--disable-gems",
      "RUBYLIB" => ruby_lib_paths,
      "RUBY_ROOT" => "#{RAILS_GEN_ROOT}/ruby",
      "RUBY_ENGINE" => "ruby",
      "RUBY_VERSION" => RUBY_VERSION,
      "RUBY_PATCHLEVEL" => nil,
      # asdf
      "ASDF_DIR" => nil,
      "ASDF_DATA_DIR" => nil,
      "ASDF_CONFIG_FILE" => nil,
      "ASDF_DEFAULT_TOOL_VERSIONS_FILENAME" => nil,
      "ASDF_RUBY_VERSION" => nil,
      "ASDF_GEM_HOME" => nil,
      # RVM
      "rvm_bin_path" => nil,
      "rvm_path" => nil,
      "rvm_prefix" => nil,
      "rvm_ruby_string" => nil,
      "rvm_version" => nil,
      # rbenv
      "RBENV_VERSION" => nil,
      "RBENV_ROOT" => nil,
      # chruby
      "RUBY_AUTO_VERSION" => nil,
      # Minimal PATH with only what we need
      "PATH" => "#{ruby_dir}/bin:#{RAILS_GEN_ROOT}/gems/bin:/usr/local/bin:/usr/bin:/bin",
      # Extra insurance
      "SHELL" => "/bin/bash",
      # Prevent Ruby from looking in user directories
      "HOME" => "/var/lib/rails-new-io/home",
      # Prevent loading of any user config
      "XDG_CONFIG_HOME" => "/var/lib/rails-new-io/config",
      "XDG_CACHE_HOME" => "/var/lib/rails-new-io/cache",
      "XDG_DATA_HOME" => "/var/lib/rails-new-io/data"
    }

    @logger.debug("Environment before command execution", {
      gem_home: ENV["GEM_HOME"],
      gem_path: ENV["GEM_PATH"],
      bundle_path: ENV["BUNDLE_PATH"],
      bundle_gemfile: ENV["BUNDLE_GEMFILE"],
      rubylib: ENV["RUBYLIB"],
      load_path: $LOAD_PATH
    })

    # Create isolation directories
    FileUtils.mkdir_p("/var/lib/rails-new-io/home")
    FileUtils.mkdir_p("/var/lib/rails-new-io/config")
    FileUtils.mkdir_p("/var/lib/rails-new-io/cache")
    FileUtils.mkdir_p("/var/lib/rails-new-io/data")

    env = if @command.start_with?("rails new")
      base_env.merge(
        "GEM_HOME" => "#{RAILS_GEN_ROOT}/gems",
        "GEM_PATH" => "#{RAILS_GEN_ROOT}/gems",
        "BUNDLE_USER_HOME" => "#{RAILS_GEN_ROOT}/bundle",
        "BUNDLE_GEMFILE" => "",
        "BUNDLE_BIN" => "",
        "BUNDLE_PATH" => "",
        "BUNDLE_APP_CONFIG" => "",
        "RUBYOPT" => "",
        "RUBYLIB" => ruby_lib_paths,
        "RUBY_ROOT" => "#{RAILS_GEN_ROOT}/ruby",
        "RUBY_VERSION" => RUBY_VERSION,
        "PATH" => "#{RAILS_GEN_ROOT}/ruby/bin:#{RAILS_GEN_ROOT}/gems/bin:/usr/local/bin:/usr/bin:/bin"
      )
    elsif @command.start_with?("bundle")
      # For bundle commands, be extra explicit about the environment
      base_env.merge(
        "GEM_HOME" => "#{RAILS_GEN_ROOT}/gems",
        "GEM_PATH" => "#{RAILS_GEN_ROOT}/gems",
        "BUNDLE_USER_HOME" => "#{RAILS_GEN_ROOT}/bundle",
        "BUNDLE_GEMFILE" => "",
        "BUNDLE_BIN" => "",
        "BUNDLE_PATH" => "",
        "BUNDLE_APP_CONFIG" => "",
        "RUBYOPT" => "",
        "RUBYLIB" => ruby_lib_paths,
        "RUBY_ROOT" => "#{RAILS_GEN_ROOT}/ruby",
        "RUBY_VERSION" => RUBY_VERSION,
        "PATH" => "#{RAILS_GEN_ROOT}/ruby/bin:#{RAILS_GEN_ROOT}/gems/bin:/usr/local/bin:/usr/bin:/bin"
      )
    else
      base_env.merge(
        "GEM_HOME" => "#{RAILS_GEN_ROOT}/gems",
        "GEM_PATH" => "#{RAILS_GEN_ROOT}/gems",
        "BUNDLE_USER_HOME" => "#{RAILS_GEN_ROOT}/bundle",
        "BUNDLE_GEMFILE" => "",
        "BUNDLE_BIN" => "",
        "BUNDLE_PATH" => "",
        "BUNDLE_APP_CONFIG" => "",
        "RUBYOPT" => "",
        "RUBYLIB" => ruby_lib_paths,
        "RUBY_ROOT" => "#{RAILS_GEN_ROOT}/ruby",
        "RUBY_VERSION" => RUBY_VERSION,
        "PATH" => "#{RAILS_GEN_ROOT}/ruby/bin:#{RAILS_GEN_ROOT}/gems/bin:/usr/local/bin:/usr/bin:/bin"
      )
    end

    @logger.debug("Environment after command execution setup", {
      gem_home: env["GEM_HOME"],
      gem_path: env["GEM_PATH"],
      bundle_path: env["BUNDLE_PATH"],
      bundle_gemfile: env["BUNDLE_GEMFILE"],
      rubylib: env["RUBYLIB"],
      command: bundle_command
    })

    # For non-rails-new commands, we need to run bundle install first
    if !@command.start_with?("rails new") && !@command.start_with?("bundle")
      @logger.debug("Running bundle install before command")
      bundle_env = env.merge(
        "BUNDLE_GEMFILE" => File.join(@work_dir, "Gemfile"),
        "BUNDLE_APP_CONFIG" => File.join(@work_dir, ".bundle")
      )
      bundle_install_cmd = "#{RAILS_GEN_ROOT}/ruby/bin/bundle install"

      Open3.popen3(bundle_env, bundle_install_cmd, chdir: @work_dir) do |stdin, stdout, stderr, wait_thr|
        stdout.each_line { |line| @logger.debug("bundle install: #{line.strip}") }
        stderr.each_line { |line| @logger.debug("bundle install error: #{line.strip}") }

        unless wait_thr.value.success?
          raise "Bundle install failed"
        end
      end
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
          @logger.debug("Command stderr: #{line.strip}")
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
          error_buffer: error_buffer.join("<br>"),
          command: bundle_command,
          directory: @work_dir,
          load_paths: [
            "#{RAILS_GEN_ROOT}/ruby/lib/ruby/3.4.0",
            platform_path,
            "#{RAILS_GEN_ROOT}/gems/gems",
            "#{RAILS_GEN_ROOT}/gems/gems/rails-#{RAILS_VERSION}/lib",
            "#{RAILS_GEN_ROOT}/gems/gems/railties-#{RAILS_VERSION}/lib"
          ]
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

  def jemalloc_lib_path
    case RbConfig::CONFIG["host_os"]
    when /darwin/
      "/usr/local/opt/jemalloc/lib/libjemalloc.dylib"
    else
      "/usr/lib/x86_64-linux-gnu/libjemalloc.so.2"
    end
  end

  def bundle_command
    @logger.debug("Starting bundle_command construction")
    @logger.debug("Command is: #{@command}")
    @logger.debug("Platform path is: #{platform_path}")

    # Debug: Check what's in the gems directory
    @logger.debug("Checking Rails installation", {
      rails_cli_path: "#{RAILS_GEN_ROOT}/gems/gems/railties-#{RAILS_VERSION}/lib/rails/cli.rb",
      rails_cli_exists: File.exist?("#{RAILS_GEN_ROOT}/gems/gems/railties-#{RAILS_VERSION}/lib/rails/cli.rb"),
      rails_lib_path: "#{RAILS_GEN_ROOT}/gems/gems/railties-#{RAILS_VERSION}/lib",
      rails_lib_exists: File.exist?("#{RAILS_GEN_ROOT}/gems/gems/railties-#{RAILS_VERSION}/lib"),
      rails_gem_path: "#{RAILS_GEN_ROOT}/gems/gems/rails-#{RAILS_VERSION}",
      rails_gem_exists: File.exist?("#{RAILS_GEN_ROOT}/gems/gems/rails-#{RAILS_VERSION}"),
      gem_home_contents: Dir.glob("#{ENV['GEM_HOME']}/*").join(", "),
      gem_home_gems: Dir.glob("#{ENV['GEM_HOME']}/gems/*").join(", "),
      rails_gem_contents: Dir.glob("#{RAILS_GEN_ROOT}/gems/gems/rails-#{RAILS_VERSION}/*").join(", "),
      railties_gem_contents: Dir.glob("#{RAILS_GEN_ROOT}/gems/gems/railties-#{RAILS_VERSION}/*").join(", ")
    })

    # Debug: Check load paths
    @logger.debug("Ruby load paths", {
      load_path: $LOAD_PATH,
      gem_path: Gem.path,
      gem_paths_exist: Gem.path.map { |p| [ p, Dir.exist?(p) ] }.to_h
    })

    command = if @command.start_with?("rails new")
      # For rails new, use the rails executable
      command_parts = @command.split
      command_parts[0] = "#{RAILS_GEN_ROOT}/gems/bin/rails"
      command_parts.join(" ").tap { |cmd| @logger.debug("Constructed rails new command: #{cmd}") }
    elsif @command.start_with?("bundle")
      # For bundle commands, use the bundle executable
      command_parts = @command.split
      command_parts[0] = "#{RAILS_GEN_ROOT}/gems/bin/bundle"
      command_parts.join(" ").tap { |cmd| @logger.debug("Constructed bundle command: #{cmd}") }
    else
      # For other rails commands, use the rails executable
      command_parts = @command.split
      command_parts[0] = "#{RAILS_GEN_ROOT}/gems/bin/rails"
      command_parts.join(" ").tap { |cmd| @logger.debug("Constructed other command: #{cmd}") }
    end

    @logger.debug("Final command: #{command}")
    command
  end
end
