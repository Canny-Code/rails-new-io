class GithubCodePushService
  require "git"
  require "fileutils"

  class Error < StandardError; end
  class GitError < Error; end
  class FileSystemError < Error; end

  def initialize(user, repository_name, source_path)
    @user = user
    @repository_name = repository_name
    @source_path = source_path
    @temp_dir = File.join(Rails.root, "tmp", "repos", SecureRandom.hex)
    @logger = Rails.logger
  end

  def push
    validate_source_path
    setup_temp_directory
    perform_git_operations
  rescue Git::Error => e
    raise GitError, "Git operation failed: #{e.message}"
  rescue Errno::ENOENT => e
    raise FileSystemError, "Source directory does not exist: #{e.message}"
  rescue Errno::EACCES, IOError => e
    raise FileSystemError, "File system operation failed: #{e.message}"
  ensure
    cleanup
  end

  private

  def validate_source_path
    unless Dir.exist?(@source_path)
      raise FileSystemError, "Source directory does not exist: #{@source_path}"
    end
  end

  def setup_temp_directory
    FileUtils.mkdir_p(@temp_dir)
    FileUtils.cp_r(File.join(@source_path, "."), @temp_dir)
  end

  def perform_git_operations
    @git = Git.init(@temp_dir)
    configure_git
    commit_files
    setup_remote
    push_to_remote
  end

  def configure_git
    @git.config("user.name", @user.name || @user.github_username)
    @git.config("user.email", @user.email || "#{@user.github_username}@users.noreply.github.com")
  end

  def commit_files
    @git.add(all: true)
    @git.commit("Initial commit")
  end

  def setup_remote
    remote_url = "https://#{@user.github_token}@github.com/#{@user.github_username}/#{@repository_name}.git"
    @git.add_remote("origin", remote_url)
  end

  def push_to_remote
    @git.push("origin", "main")
  end

  def cleanup
    FileUtils.rm_rf(@temp_dir) if Dir.exist?(@temp_dir)
  end
end
