# frozen_string_literal: true

require "open3"

# Handles all local git operations within a specific directory
class LocalGitService
  class Error < StandardError; end

  ALLOWED_COMMANDS = {
    "git init --quiet" => true,
    "git config user.name 'railsnew.io'" => true,
    "git config user.email 'bot@railsnew.io'" => true,
    "git rev-parse --abbrev-ref HEAD" => true,
    "git branch -M main" => true,
    "git remote -v" => true,
    "git status --porcelain" => true,
    "git config --list" => true,
    "git -c core.askpass=false push -v -u origin main" => true
  }.freeze

  ALLOWED_COMMAND_PATTERNS = [
    /\Agit remote (add|set-url) origin https:\/\/[a-zA-Z0-9@\-_.\/]+\z/,
    /\Agit add \. && git -c init\.defaultBranch=main commit -m '.+'\z/,
    /\Agit add \. && git commit -m '.+'\z/
  ].freeze

  attr_reader :working_directory, :logger

  def initialize(working_directory:, logger: Rails.logger)
    @working_directory = working_directory
    @logger = logger
  end

  def prepare_git_repository(remote_url:)
    unless File.directory?(working_directory)
      logger.error("Working directory not found", { path: working_directory })
      raise Error, "Working directory not found at #{working_directory}"
    end

    init_repository
    ensure_main_branch
    set_remote(url: remote_url)
  end

  def init_repository
    in_working_directory do
      run_command!("git init --quiet")
      run_command!("git config user.name 'railsnew.io'")
      run_command!("git config user.email 'bot@railsnew.io'")
    end
  end

  def create_initial_commit(message:)
    in_working_directory do
      run_command!("git add . && git -c init.defaultBranch=main commit -m '#{message}'")
    end
  end

  def ensure_main_branch
    in_working_directory do
      current_branch = run_command("git rev-parse --abbrev-ref HEAD").strip
      return if current_branch == "main"

      run_command!("git branch -M main")
    end
  end

  def set_remote(url:)
    in_working_directory do
      remotes = run_command("git remote -v").strip

      if remotes.include?("origin")
        current_url = remotes[/origin\s+(\S+)/, 1]
        return if current_url == url

        run_command!("git remote set-url origin #{url}")
      else
        run_command!("git remote add origin #{url}")
      end
    end
  end

  def push_to_remote(token:, repo_url:)
    in_working_directory do
      repo_url_with_token = repo_url.sub("https://", "https://#{token}@")

      # Set URL with token temporarily
      run_command!("git remote set-url origin #{repo_url_with_token}")

      # Push with credentials
      ENV["GIT_TERMINAL_PROMPT"] = "0" # Ensure git never prompts for input
      success = nil
      begin
        success = system("git -c core.askpass=false push -v -u origin main")
      ensure
        # Reset URL without token - ALWAYS do this, even if push fails
        run_command!("git remote set-url origin #{repo_url}")
      end

      unless success
        git_status = run_command("git status --porcelain")
        git_config = run_command("git config --list")
        logger.error("Failed to push to GitHub", {
          git_status: git_status.strip,
          current_branch: "main",
          git_config: git_config.strip,
          current_path: Dir.pwd
        })
        raise Error, "Failed to push to GitHub"
      end
    end
  end

  def commit_changes(message:)
    in_working_directory do
      run_command!("git add . && git commit -m '#{message}'")
    end
  end

  private

  def in_working_directory(&block)
    unless File.directory?(working_directory)
      logger.error("Working directory not found", { path: working_directory })
      raise Error, "Working directory not found at #{working_directory}"
    end

    original_dir = Dir.pwd
    begin
      Dir.chdir(working_directory)
      yield
    ensure
      Dir.chdir(original_dir) if original_dir && File.directory?(original_dir)
    end
  end

  def run_command!(command)
    validate_command!(command)
    success = system(command)
    unless success
      git_status = run_command("git status --porcelain")
      logger.error("Git command failed", {
        command: command,
        git_status: git_status.strip,
        current_path: Dir.pwd
      })
      raise Error, "Git command failed: #{command}"
    end
  end

  def run_command(command)
    validate_command!(command)
    output, status = Open3.capture2(command)
    unless status.success?
      logger.error("Git command failed", {
        command: command,
        status: status,
        current_path: Dir.pwd
      })
      raise Error, "Git command failed: #{command}"
    end
    output
  end

  def validate_command!(command)
    return if ALLOWED_COMMANDS[command]
    return if ALLOWED_COMMAND_PATTERNS.any? { |pattern| pattern.match?(command) }

    logger.error("Invalid Git command", { command: command })
    raise Error, "Invalid Git command: #{command}"
  end
end
