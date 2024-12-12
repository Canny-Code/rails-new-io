class GitRepo
  REPO_NAME = "rails-new-io-data"
  class GitSyncError < StandardError; end

  def initialize(user:, repo_name:)
    @user = user
    @repo_path = Rails.root.join("tmp", "git_repos", user.id.to_s, repo_name)
    @repo_name = repo_name
    ensure_repo_exists
  end

  def write_model(model)
    ensure_fresh_repo

    case model
    when GeneratedApp
      write_generated_app(model)
    when Ingredient
      write_ingredient(model)
    when Recipe
      write_recipe(model)
    end

    push_to_remote
  end

  private

  def repo_name
    if Rails.env.development?
      "#{REPO_NAME}-dev"
    elsif Rails.env.test?
      "#{REPO_NAME}-test"
    elsif Rails.env.production?
      REPO_NAME
    else
      raise ArgumentError, "Unknown Rails environment: #{Rails.env}"
    end
  end

  def ensure_repo_exists
    return if remote_repo_exists?

    create_local_repo
    create_github_repo
    setup_remote
    create_initial_structure
  end

  def remote_repo_exists?
    github_client.repository?("#{@user.github_username}/#{repo_name}")
  rescue Octokit::Error => e
    Rails.logger.error("Failed to check GitHub repository: #{e.message}")
    false
  end

  def create_local_repo
    # Ensure parent directory exists first
    FileUtils.mkdir_p(File.dirname(@repo_path))

    # Remove existing repo if it exists
    FileUtils.rm_rf(@repo_path) if File.exist?(@repo_path)

    # Create fresh directory and initialize git
    FileUtils.mkdir_p(@repo_path)
    git = Git.init(@repo_path)

    # Configure git to avoid template issues
    git.config("init.templateDir", "")

    @git = git
  end

  def create_github_repo
    github_client.create_repository(
      repo_name,
      private: false,
      description: "Data repository for rails-new.io"
    )
  end

  def create_initial_structure
    %w[generated_apps ingredients recipes].each do |dir|
      FileUtils.mkdir_p(File.join(@repo_path, dir))
    end

    File.write(File.join(@repo_path, "README.md"), readme_content)

    git.add(all: true)
    git.commit("Initial commit")
  end

  def write_generated_app(app)
    path = File.join(@repo_path, "generated_apps", app.id.to_s)
    FileUtils.mkdir_p(path)

    write_json(path, "current_state.json", {
      name: app.name,
      recipe_id: app.recipe_id,
      configuration: app.configuration_options
    })

    write_json(path, "history.json", app.app_changes.map(&:to_git_format))
  end

  def write_ingredient(ingredient)
    path = File.join(@repo_path, "ingredients", ingredient.name.parameterize)
    FileUtils.mkdir_p(path)

    File.write(File.join(path, "template.rb"), ingredient.template_content)
    write_json(path, "metadata.json", {
      name: ingredient.name,
      description: ingredient.description,
      conflicts_with: ingredient.conflicts_with,
      requires: ingredient.requires,
      configures_with: ingredient.configures_with
    })
  end

  def write_recipe(recipe)
    path = File.join(@repo_path, "recipes", recipe.id.to_s)
    FileUtils.mkdir_p(path)

    write_json(path, "manifest.json", {
      name: recipe.name,
      cli_flags: recipe.cli_flags,
      ruby_version: recipe.ruby_version,
      rails_version: recipe.rails_version
    })

    write_json(path, "ingredients.json",
      recipe.recipe_ingredients.order(:position).map(&:to_git_format)
    )
  end

  def ensure_fresh_repo
    git.fetch
    git.reset_hard("origin/main")
    git.pull
  end

  def push_to_remote
    git.push("origin", "main")
  rescue Git::Error => e
    # Handle push conflicts
    Rails.logger.error "Git push failed: #{e.message}"
    raise GitSyncError, "Failed to sync changes to GitHub"
  end

  def git
    @git ||= Git.open(@repo_path)
  end

  def github_client
    @github_client ||= Octokit::Client.new(access_token: @user.github_token)
  end

  def write_json(path, filename, data)
    File.write(
      File.join(path, filename),
      JSON.pretty_generate(data)
    )
  end

  def setup_remote
    remote_url = "https://#{@user.github_token}@github.com/#{@user.github_username}/#{repo_name}.git"
    git.add_remote("origin", remote_url)
  end
end