class DataRepository < GitRepo
  BASE_NAME = "rails-new-io-data"

  class << self
    def name_for_environment
      if Rails.env.development?
        "#{BASE_NAME}-dev"
      elsif Rails.env.test?
        "#{BASE_NAME}-test"
      elsif Rails.env.production?
        BASE_NAME
      else
        raise ArgumentError, "Unknown Rails environment: #{Rails.env}"
      end
    end
  end

  def initialize(user:)
    super(user: user, repo_name: self.class.name_for_environment)
  end

  def template_path(ingredient)
    File.join(repo_path, "ingredients", ingredient.name.parameterize, "template.rb")
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
  end

  protected

  def ensure_committable_state
    %w[ingredients recipes].each do |dir|
      FileUtils.mkdir_p(File.join(repo_path, dir))
      FileUtils.touch(File.join(repo_path, dir, ".keep"))
    end
    File.write(File.join(repo_path, "README.md"), readme_content)
  end

  def write_generated_app(app)
    raise NotImplementedError, "Generated apps are stored in their own repositories"
  end

  private

  def write_ingredient(ingredient)
    path = File.join(repo_path, "ingredients", ingredient.name.parameterize)
    FileUtils.mkdir_p(path)

    write_json(path, "metadata.json", {
      name: ingredient.name,
      category: ingredient.category,
      description: ingredient.description,
      configures_with: ingredient.configures_with,
      requires: ingredient.requires,
      conflicts_with: ingredient.conflicts_with,
      created_at: ingredient.created_at.iso8601,
      updated_at: ingredient.updated_at.iso8601
    })

    File.write(File.join(path, "template.rb"), ingredient.template_content)
  end

  def write_recipe(recipe)
    path = File.join(repo_path, "recipes", recipe.name)
    FileUtils.mkdir_p(path)

    write_json(path, "metadata.json", {
      name: recipe.name,
      description: recipe.description,
      cli_flags: recipe.cli_flags,
      created_at: recipe.created_at.iso8601,
      updated_at: recipe.updated_at.iso8601
    })

    write_json(path, "ingredients.json", recipe.recipe_ingredients.map { |ri|
      {
        name: ri.ingredient.name,
        position: ri.position,
        configuration: ri.configuration
      }
    })
  end

  def ensure_fresh_repo
    # If repo doesn't exist locally, clone it or create it
    unless File.exist?(repo_path)
      if remote_repo_exists?
        Git.clone(
          "https://#{user.github_token}@github.com/#{user.github_username}/#{repo_name}.git",
          repo_name,
          path: File.dirname(repo_path)
        )
        @git = Git.open(repo_path)
      else
        create_local_repo
        ensure_github_repo_exists
        setup_remote
        push_to_remote
      end
    end

    # If repo exists and remote exists, fetch latest changes
    if remote_repo_exists?
      git.fetch
      if remote_branch_exists?("main")
        git.reset_hard("origin/main")
      end
    end

    # Check if directories exist in repo
    dirs_exist = %w[ingredients recipes].all? do |dir|
      File.directory?(File.join(repo_path, dir))
    end

    unless dirs_exist
      ensure_committable_state
      git.add(all: true)
      if git.status.changed.any? || git.status.added.any?
        git.commit("Initialize repository structure")
        push_to_remote if remote_repo_exists?
      end
    end
  end

  def push_to_remote
    git.push("origin", "main")
  rescue Git::Error => e
    Rails.logger.error "Git push failed: #{e.message}"
    raise GitSyncError, "Failed to sync changes to GitHub"
  end

  def readme_content
    "# Data Repository\nThis repository contains data for rails-new.io"
  end

  def repository_description
    "Data repository for rails-new.io"
  end

  def write_json(path, filename, content)
    File.write(File.join(path, filename), content.to_json)
  end
end
