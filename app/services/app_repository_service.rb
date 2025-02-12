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
    git_service.prepare_git_repository(remote_url: generated_app.github_repo_url)
    git_service.create_initial_commit(message: generated_app.to_commit_message)
  end

  def push_to_remote
    app_directory_path = File.join(generated_app.workspace_path, generated_app.name)

    # Validate directory exists before trying to chdir
    unless File.directory?(app_directory_path)
      logger.error("Rails app directory not found", { path: app_directory_path })
      raise "Rails app directory not found at #{app_directory_path}"
    end

    # Ensure we're on main branch before pushing
    git_service.ensure_main_branch

    git_service.push_to_remote(
      token: user.github_token,
      repo_url: generated_app.github_repo_url
    )
  end

  def commit_changes_after_applying_ingredient(ingredient)
    git_service.commit_changes(message: ingredient.to_commit_message)
  end

  def commit_changes_after_gemfile_lock_update(message)
    git_service.commit_changes(message:)
  end

  private

  def git_service
    @git_service ||= LocalGitService.new(
      working_directory: File.join(generated_app.workspace_path, generated_app.name),
      logger: logger
    )
  end
end
