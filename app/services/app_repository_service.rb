# app/services/app_repository_service.rb
class AppRepositoryService < GithubRepositoryService
  attr_reader :generated_app

  def initialize(generated_app)
    @generated_app = generated_app
    super(
      user: generated_app.user,
      logger: AppGeneration::Logger.new(generated_app)
    )
  end

  def create_github_repository
    generated_app.create_github_repo!

    repo_name = generated_app.name

    response = create_repository(
      repo_name: repo_name,
      auto_init: false
    )

    generated_app.update!(
      github_repo_name: repo_name,
      github_repo_url: response.html_url
    )

    response
  end

  def push_app_files
    return unless File.directory?(generated_app.source_path)

    app_dir = File.join(generated_app.source_path, generated_app.name)

    unless File.directory?(app_dir)
      logger.error("Rails app directory not found", { path: app_dir })
      raise "Rails app directory not found at #{app_dir}"
    end

    original_dir = Dir.pwd

    begin
      Dir.chdir(app_dir)
      validate_git_repository!
      create_initial_commit_if_needed!
      ensure_main_branch!
      setup_remote!
      push_to_remote!
    ensure
      Dir.chdir(original_dir) if original_dir && File.directory?(original_dir)
    end
  end

  private

  def validate_git_repository!
    unless File.directory?(".git")
      logger.error("Not a git repository", { path: Dir.pwd })
      raise "Not a git repository at #{Dir.pwd}"
    end
  end

  def create_initial_commit_if_needed!
    return if head_exists?

    success = system("git add . && git -c init.defaultBranch=main commit -m '#{initial_commit_message}'")

    unless success
      git_status = run_git_command("git status --porcelain")
      logger.error("Failed to create initial commit", {
        git_status: git_status.strip
      })
      raise "Failed to create initial commit"
    end
  end

  def ensure_main_branch!
    current_branch = run_git_command("git rev-parse --abbrev-ref HEAD").strip
    return if current_branch == "main"

    success = system("git branch -M main")
    unless success
      logger.error("Failed to rename branch to main", {
        current_branch: current_branch
      })
      raise "Failed to rename branch to main"
    end
  end

  def setup_remote!
    remotes = run_git_command("git remote -v").strip

    if remotes.include?("origin")
      current_url = remotes[/origin\s+(\S+)/, 1]
      if current_url != generated_app.github_repo_url
        success = system("git remote set-url origin #{generated_app.github_repo_url}")
        unless success
          logger.error("Failed to update remote URL")
          raise "Failed to update remote URL"
        end
      end
    else
      success = system("git remote add origin #{generated_app.github_repo_url}")
      unless success
        git_status = run_git_command("git status --porcelain")
        logger.error("Failed to add remote", {
          current_remotes: remotes,
          git_status: git_status.strip
        })
        raise "Failed to add git remote"
      end
    end
  end

  def push_to_remote!
    # Set URL with token for push
    repo_url_with_token = generated_app.github_repo_url.sub("https://", "https://#{user.github_token}@")
    system("git remote set-url origin #{repo_url_with_token}")

    # Push to remote
    success = system("git push -v -u origin main")

    # Reset URL without token
    system("git remote set-url origin #{generated_app.github_repo_url}")

    unless success
      git_status = run_git_command("git status --porcelain")
      git_config = run_git_command("git config --list")
      logger.error("Failed to push to GitHub", {
        git_status: git_status.strip,
        current_branch: "main",
        git_config: git_config.strip
      })
      raise "Failed to push to GitHub"
    end
  end

  def run_git_command(command)
    `#{command}`
  end

  def initial_commit_message
    ingredients_message = if generated_app.recipe.ingredients.any?
      <<~INGREDIENTS_MESSAGE
      ============
      Ingredients:
      ============

      #{generated_app.recipe.ingredients.map(&:to_commit_message).join("\n\n")}
      INGREDIENTS_MESSAGE
    else
      ""
    end

    <<~INITIAL_COMMIT_MESSAGE
    Initial commit by railsnew.io

    command line flags:

    #{generated_app.recipe.cli_flags.squish.strip}

    #{ingredients_message}
    INITIAL_COMMIT_MESSAGE
  end

  def head_exists?
    !run_git_command("git rev-parse --verify HEAD 2>/dev/null").empty?
  end
end
