class GitRepo
  class Error < StandardError; end
  class GitSyncError < Error; end

  def initialize(user:, repo_name:)
    @user = user
    @repo_path = Rails.root.join("tmp", "git_repos", user.id.to_s, repo_name)
    @repo_name = repo_name
  end

  def commit_changes(message:, author:)
    puts "\n=== GitRepo#commit_changes ==="
    puts "Checking if repo exists at: #{repo_path}"

    if File.exist?(repo_path)
      puts "Local repo exists, checking remote"
      if remote_repo_exists?
        puts "Remote exists, fetching latest changes"
        git.fetch
        git.reset_hard("origin/main")
      else
        puts "Remote doesn't exist, creating it"
        ensure_github_repo_exists
        setup_remote
      end
    else
      puts "Local repo doesn't exist, checking remote"
      if remote_repo_exists?
        puts "Remote repo exists, cloning"
        Git.clone(
          "https://#{user.github_token}@github.com/#{user.github_username}/#{repo_name}.git",
          repo_name,
          path: File.dirname(repo_path)
        )
        @git = Git.open(repo_path)
      else
        puts "Remote repo doesn't exist, creating new repo"
        create_local_repo
        ensure_github_repo_exists
        setup_remote
      end
    end

    puts "Ensuring committable state"
    ensure_committable_state

    puts "Configuring git user"
    git.config("user.name", author.name || author.github_username)
    git.config("user.email", author.email || "#{author.github_username}@users.noreply.github.com")

    puts "Adding and committing changes"
    git.add(all: true)
    git.commit(message)

    puts "Pushing changes"
    current_branch = git.branch.name
    git.push("origin", current_branch)
  end

  protected

  attr_reader :user, :repo_path, :repo_name

  def git
    @git ||= begin
      if File.exist?(File.join(@repo_path, ".git"))
        Git.open(@repo_path)
      else
        create_local_repo
        @git
      end
    end
  end

  def create_local_repo
    puts "\n=== GitRepo#create_local_repo ==="
    puts "Creating directory: #{File.dirname(@repo_path)}"
    FileUtils.mkdir_p(File.dirname(@repo_path))

    if File.exist?(@repo_path)
      puts "Removing existing repo path: #{@repo_path}"
      FileUtils.rm_rf(@repo_path)
    end

    puts "Creating repo directory: #{@repo_path}"
    FileUtils.mkdir_p(@repo_path)

    puts "Initializing git repo"
    @git = Git.init(@repo_path)

    puts "Configuring git"
    @git.config("init.templateDir", "")
    @git.config("init.defaultBranch", "main")
  end

  def remote_repo_exists?
    puts "\n=== GitRepo#remote_repo_exists? ==="
    puts "Checking if repo exists: #{user.github_username}/#{repo_name}"
    result = github_client.repository?("#{user.github_username}/#{repo_name}")
    puts "Result: #{result}"
    result
  rescue Octokit::Error => e
    Rails.logger.error("Failed to check GitHub repository: #{e.message}")
    false
  end

  def create_github_repo
    github_client.create_repository(
      repo_name,
      private: false,
      description: repository_description
    )
  end

  def setup_remote
    remote_url = "https://#{user.github_token}@github.com/#{user.github_username}/#{repo_name}.git"
    git.add_remote("origin", remote_url)
  end

  def github_client
    @_github_client ||= Octokit::Client.new(access_token: user.github_token)
  end

  def write_json(path, filename, data)
    File.write(
      File.join(path, filename),
      JSON.pretty_generate(data)
    )
  end

  def ensure_committable_state
    puts "\n=== Ensuring committable state ==="
    puts "Before writing: #{Dir.glob("#{repo_path}/*").inspect}"
    File.write(File.join(repo_path, "README.md"), default_readme_content)
    puts "After writing: #{Dir.glob("#{repo_path}/*").inspect}"
    puts "README.md content:"
    puts File.read(File.join(repo_path, "README.md"))
  end

  def default_readme_content
    "# Repository\nCreated via railsnew.io"
  end

  private

  def repository_description
    "Repository created via railsnew.io"
  end

  def ensure_github_repo_exists
    return if remote_repo_exists?
    create_github_repo
  end
end
