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

  def initialize_repository
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

  def push_app_files(source_path:)
    return unless File.directory?(source_path)

    app_dir = File.join(source_path, generated_app.name)
    unless File.directory?(app_dir)
      logger.error("Rails app directory not found", { path: app_dir })
      raise "Rails app directory not found at #{app_dir}"
    end

    original_dir = Dir.pwd
    begin
      Dir.chdir(app_dir)

      unless File.directory?(".git")
        logger.error("Not a git repository", { path: app_dir })
        raise "Not a git repository at #{app_dir}"
      end

      if `git rev-parse --verify HEAD 2>/dev/null`.empty?
        init_output = `git add . 2>&1 && git -c init.defaultBranch=main commit -m "#{initial_commit_message}" 2>&1`

        unless $?.success?
          logger.error("Failed to create initial commit", {
            error: init_output,
            git_status: `git status --porcelain 2>&1`.strip,
            exit_code: $?.exitstatus
          })
          raise "Failed to create initial commit:\n#{init_output}"
        end
      end

      current_branch = `git rev-parse --abbrev-ref HEAD`.strip
      if current_branch != "main"
        rename_output = `git branch -M main 2>&1`
        unless $?.success?
          logger.error("Failed to rename branch to main", {
            error: rename_output,
            current_branch: current_branch,
            exit_code: $?.exitstatus
          })
          raise "Failed to rename branch to main:\n#{rename_output}"
        end
      end

      remotes = `git remote -v`.strip
      if remotes.include?("origin")
        current_url = remotes[/origin\s+(\S+)/, 1]
        if current_url != generated_app.github_repo_url
          system("git remote set-url origin #{generated_app.github_repo_url}")
        end
      else
        add_output = `git remote add origin #{generated_app.github_repo_url} 2>&1`
        unless $?.success?
          logger.error("Failed to add remote", {
            error: add_output,
            current_remotes: `git remote -v 2>&1`.strip,
            git_status: `git status --porcelain 2>&1`.strip,
            exit_code: $?.exitstatus
          })
          raise "Failed to add git remote:\n#{add_output}"
        end
      end

      repo_url_with_token = generated_app.github_repo_url.sub("https://", "https://#{user.github_token}@")
      system("git remote set-url origin #{repo_url_with_token}")

      push_output = `git push -v -u origin main 2>&1`

      system("git remote set-url origin #{generated_app.github_repo_url}")

      unless $?.success?
        logger.error("Failed to push to GitHub", {
          error: push_output,
          git_status: `git status --porcelain 2>&1`.strip,
          current_branch: "main",
          exit_code: $?.exitstatus,
          git_config: `git config --list 2>&1`.strip
        })
        raise "Failed to push to GitHub:\n#{push_output}"
      end
    ensure
      Dir.chdir(original_dir) if original_dir && File.directory?(original_dir)
    end
  end

  private

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
end
