# app/services/app_repository_service.rb
class AppRepositoryService < GithubRepositoryService
  attr_reader :generated_app

  def initialize(generated_app, logger)
    @generated_app = generated_app
    @logger = logger
    super(
      user: generated_app.user,
      logger: @logger
    )
  end

  def create_github_repository
    generated_app.start_github_repo_creation!

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

  def create_initial_commit
    prepare_git_repository

    app_directory_path = File.join(generated_app.workspace_path, generated_app.name)

    in_app_directory(app_directory_path) do
      success = system("git add . && git -c init.defaultBranch=main commit -m '#{initial_commit_message}'")

      unless success
        git_status = run_command("git status --porcelain")
        logger.error("Failed to create initial commit", {
          git_status: git_status.strip
        })
          raise "Failed to create initial commit"
      end
    end
  end

  def push_to_remote
    app_directory_path = File.join(generated_app.workspace_path, generated_app.name)

    # Validate directory exists before trying to chdir
    unless File.directory?(app_directory_path)
      logger.error("Rails app directory not found", { path: app_directory_path })
      raise "Rails app directory not found at #{app_directory_path}"
    end

    repo_url_with_token = generated_app.github_repo_url.sub("https://", "https://#{user.github_token}@")

    # Push to remote
    in_app_directory(app_directory_path) do
      validate_git_repository
      ensure_main_branch

      # Set up remote if needed
      remotes = run_command("git remote -v").strip
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
          git_status = run_command("git status --porcelain")
          logger.error("Failed to add remote", {
            current_remotes: remotes,
            git_status: git_status.strip
          })
          raise "Failed to add git remote"
        end
      end

      puts "DEBUG: Setting git remote URL with token"
      system("git remote set-url origin #{repo_url_with_token}")

      # Ensure git never prompts for input
      ENV["GIT_TERMINAL_PROMPT"] = "0"
      puts "DEBUG: Current git remote config:"
      puts run_command("git remote -v")
      puts "DEBUG: Attempting git push..."
      success = system("git -c core.askpass=false push -v -u origin main")
      puts "DEBUG: Git push completed with status: #{success}"

      puts "DEBUG: Resetting remote URL"
      # Reset URL without token
      system("git remote set-url origin #{generated_app.github_repo_url}")

      unless success
        git_status = run_command("git status --porcelain")
        git_config = run_command("git config --list")
        logger.error("Failed to push to GitHub", {
          git_status: git_status.strip,
          current_branch: "main",
          git_config: git_config.strip,
          current_path: Dir.pwd
        })
        raise "Failed to push to GitHub"
      end
    end
  end

  def commit_changes_after_applying_ingredient(ingredient)
    app_directory_path = File.join(generated_app.workspace_path, generated_app.name)

    in_app_directory(app_directory_path) do
      commit_message = <<~COMMIT_MESSAGE
      Apply ingredient:

      #{ingredient.to_commit_message}
      COMMIT_MESSAGE

      system("git add . && git commit -m '#{commit_message}'")
    end
  end

  private

  def in_app_directory(path)
    original_dir = Dir.pwd
    Dir.chdir(path)
    yield
  ensure
    Dir.chdir(original_dir)
  end

  def prepare_git_repository
    return unless File.directory?(generated_app.workspace_path)

    app_directory_path = File.join(generated_app.workspace_path, generated_app.name)
    unless File.directory?(app_directory_path)
      logger.error("Rails app directory not found", { path: app_directory_path })
      raise "Rails app directory not found at #{app_directory_path}"
    end

    in_app_directory(app_directory_path) do
      validate_git_repository
      ensure_main_branch
    end
  end

  def validate_git_repository
    unless File.directory?(".git")
      logger.error("Not a git repository", { path: Dir.pwd })
      raise "Not a git repository at #{Dir.pwd}"
    end
  end

  def ensure_main_branch
    current_branch = run_command("git rev-parse --abbrev-ref HEAD").strip
    return if current_branch == "main"

    success = system("git branch -M main")
    unless success
      logger.error("Failed to rename branch to main", {
        current_branch: current_branch
      })
      raise "Failed to rename branch to main"
    end
  end

  def setup_remote
    remotes = run_command("git remote -v").strip

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
        git_status = run_command("git status --porcelain")
        logger.error("Failed to add remote", {
          current_remotes: remotes,
          git_status: git_status.strip
        })
        raise "Failed to add git remote"
      end
    end
  end

  def run_command(command)
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
    !run_command("git rev-parse --verify HEAD 2>/dev/null").empty?
  end
end
