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

  def initialize(generated_app)
    @generated_app = generated_app
    @logger = AppGeneration::Logger.new(generated_app)
    @user = generated_app.user
    @repository_name = generated_app.github_repo_name
    @source_path = generated_app.source_path
  end

  def execute
    validate_app_state!
    validate_source_directory!

    generated_app.push_to_github!
    push_code

    generated_app.update!(github_repo_url: repository_url)
    @logger.info("GitHub push finished successfully", {
      repository_url: repository_url
    })
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

  attr_reader :generated_app, :user, :repository_name, :source_path

  def validate_app_state!
    unless generated_app.app_status.generating?
      raise InvalidStateError.new(INVALID_STATE_MESSAGE)
    end
  end

  def validate_source_directory!
    source_path = @generated_app.source_path
    unless File.directory?(source_path)
      raise FileSystemError, "Source directory does not exist: #{source_path}"
    end
  end

  def push_code
    @git = Git.open("#{@source_path}/#{generated_app.name}")
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

  def repository_url
    "https://github.com/#{user.github_username}/#{repository_name}"
  end

  def cleanup
    return if Rails.env.development?

    FileUtils.rm_rf(@source_path)
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
