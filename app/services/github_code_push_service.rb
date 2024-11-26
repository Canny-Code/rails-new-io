class GithubCodePushService
  require "git"
  require "fileutils"

  class Error < StandardError; end
  class FileSystemError < Error
    def initialize(msg)
      super("File system error: #{msg}")
    end
  end
  class GitError < Error
    def initialize(msg)
      super("Git error: #{msg}")
    end
  end
  class InvalidStateError < Error
    def initialize(msg)
      super(msg)
    end
  end

  INVALID_STATE_MESSAGE = "App must be in generating state to execute"

  def initialize(generated_app, source_path)
    @generated_app = generated_app
    @user = generated_app.user
    @repository_name = generated_app.github_repository_name
    @source_path = source_path
    @temp_dir = File.join(Rails.root, "tmp", "repos", SecureRandom.hex)
  end

  def execute
    validate_source_path
    validate_current_state
    setup_repository
    push_code
    update_app_status
  rescue Git::Error => e
    handle_error(e, :git)
  rescue FileSystemError, Errno::EACCES, Errno::EPERM, IOError => e
    handle_error(e, :file_system)
  rescue InvalidStateError => e
    handle_error(e, :invalid_state)
  rescue StandardError => e
    handle_error(e, :standard)
  ensure
    cleanup
  end

  private

  attr_reader :generated_app, :user, :repository_name, :source_path, :temp_dir

  def setup_repository
    setup_temp_directory
  end

  def validate_current_state
    unless generated_app.app_status.generating?
      raise InvalidStateError.new(INVALID_STATE_MESSAGE)
    end
  end

  def validate_source_path
    unless Dir.exist?(@source_path)
      raise FileSystemError.new("Source directory does not exist: #{@source_path}")
    end
  end

  def setup_temp_directory
    FileUtils.mkdir_p(@temp_dir)
    FileUtils.cp_r(File.join(@source_path, "."), @temp_dir)
  end

  def push_code
    @git = Git.init(temp_dir)
    configure_git
    commit_files
    setup_remote
    push_to_remote
  end

  def configure_git
    @git.config("user.name", user.name || user.github_username)
    @git.config("user.email", user.email || "#{user.github_username}@users.noreply.github.com")
  end

  def commit_files
    @git.add(all: true)
    @git.commit("Initial commit")
  end

  def setup_remote
    remote_url = "https://#{user.github_token}@github.com/#{user.github_username}/#{repository_name}.git"
    @git.add_remote("origin", remote_url)
  end

  def push_to_remote
    @git.push("origin", "main")
  end

  def update_app_status
    generated_app.update!(github_repo_url: repository_url)
    generated_app.push_to_github!
  end

  def repository_url
    "https://github.com/#{user.github_username}/#{repository_name}"
  end

  def cleanup
    FileUtils.rm_rf(temp_dir)
  end

  def handle_error(error, type)
    message = error.message.split(" - ").first
    message = message.sub(/^[^:]+: /, "")

    generated_app.app_status.fail!(message)

    case type
    when :git
      raise GitError.new(message)
    when :file_system
      raise FileSystemError.new(message)
    when :invalid_state
      raise InvalidStateError.new(message)
    else
      raise Error, message
    end
  end
end
