class GitRepo
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

  def initialize(user:, repo_name:, source_path: nil, cleanup_after_push: false)
    @user = user
    @source_path = source_path
    @repo_name = repo_name
    @cleanup_after_push = cleanup_after_push
    @logger = Rails.logger
  end

  def clone
    raise GitError, "Repository does not exist" unless repository_exists?

    # Get current tree SHA
    ref = github_client.ref(repo_full_name, "heads/main")
    commit = github_client.commit(repo_full_name, ref.object.sha)
    base_tree = commit.commit.tree

    # Create blobs and new tree
    new_tree = create_tree_from_files(base_tree.sha)

    # Create commit
    new_commit = github_client.create_commit(
      repo_full_name,
      "Clone repository",
      new_tree.sha,
      ref.object.sha,
      author: { name: user.name || user.github_username,
                email: user.email || "#{user.github_username}@users.noreply.github.com" }
    )

    # Update reference
    github_client.update_ref(
      repo_full_name,
      "heads/main",
      new_commit.sha
    )
  rescue Octokit::Error => e
    raise GitError, e.message
  end

  def commit_changes(message:, author:)
    validate_source_directory!
    ensure_github_repo_exists

    # Get current tree SHA
    ref = github_client.ref(repo_full_name, "heads/main")
    commit = github_client.commit(repo_full_name, ref.object.sha)
    base_tree = commit.commit.tree

    # Create blobs and new tree
    new_tree = create_tree_from_files(base_tree.sha)

    # Create commit
    new_commit = github_client.create_commit(
      repo_full_name,
      message,
      new_tree.sha,
      ref.object.sha,
      author: { name: author.name || author.github_username,
                email: author.email || "#{author.github_username}@users.noreply.github.com" }
    )

    # Update reference
    github_client.update_ref(
      repo_full_name,
      "heads/main",
      new_commit.sha
    )

    cleanup if @cleanup_after_push
  rescue Octokit::Error => e
    raise GitError, e.message
  end

  def create_repository
    return if repository_exists?

    github_client.create_repository(
      repo_name,
      private: false,
      description: repository_description,
      auto_init: true,
      default_branch: "main"
    )

    commit_changes(
      message: "Initialize repository structure",
      author: user
    )
  end

  protected

  attr_reader :user, :repo_name, :source_path

  def create_tree_from_files(base_tree_sha)
    tree_items = []

    # Add README if it doesn't exist
    tree_items << {
      path: "README.md",
      mode: "100644",
      type: "blob",
      content: readme_content
    }

    # Add any additional files from source directory
    if source_path && File.directory?(source_path)
      Dir.glob("#{source_path}/**/*", File::FNM_DOTMATCH).each do |file_path|
        next if File.directory?(file_path)
        next if file_path.end_with?("/.") || file_path.end_with?("/..")

        relative_path = file_path.sub("#{source_path}/", "")
        content = File.read(file_path)

        tree_items << {
          path: relative_path,
          mode: "100644",
          type: "blob",
          content: content
        }
      end
    end

    github_client.create_tree(
      repo_full_name,
      tree_items,
      base_tree: base_tree_sha
    )
  end

  def remote_repo_exists?
    github_client.repository?(repo_full_name)
  rescue Octokit::Error => e
    Rails.logger.error("Failed to check GitHub repository: #{e.message}")
    false
  end

  def repo_full_name
    "#{user.github_username}/#{repo_name}"
  end

  def github_client
    @github_client ||= Octokit::Client.new(access_token: user.github_token)
  end

  def readme_content
    "# Repository\nCreated via railsnew.io"
  end

  def repository_description
    "Repository created via railsnew.io"
  end

  def validate_source_directory!
    return if source_path.nil?

    unless File.directory?(source_path)
      raise FileSystemError, "Source directory does not exist: #{source_path}"
    end
  end

  def cleanup
    return if Rails.env.development?
    return if source_path.nil?

    FileUtils.rm_rf(source_path)
  end

  def ensure_github_repo_exists
    return if remote_repo_exists?
    create_repository
  end

  def repository_exists?
    github_client.repository?("#{user.github_username}/#{repo_name}")
  rescue Octokit::Error => e
    raise GitError, "Failed to check if repository exists: #{e.message}"
  end
end
