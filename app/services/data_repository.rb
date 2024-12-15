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

  def ensure_committable_state
    %w[generated_apps ingredients recipes].each do |dir|
      FileUtils.mkdir_p(File.join(repo_path, dir))
      FileUtils.touch(File.join(repo_path, dir, ".keep"))
    end
    File.write(File.join(repo_path, "README.md"), readme_content)
  end

  def write_generated_app(app)
    path = File.join(repo_path, "generated_apps", app.id.to_s)
    FileUtils.mkdir_p(path)

    write_json(path, "current_state.json", {
      name: app.name,
      recipe_id: app.recipe_id,
      configuration: app.configuration_options
    })

    write_json(path, "history.json", app.app_changes.map(&:to_git_format))
  end

  def write_ingredient(ingredient)
    path = File.join(repo_path, "ingredients", ingredient.name.parameterize)
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
    path = File.join(repo_path, "recipes", recipe.id.to_s)
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
    Rails.logger.error "Git push failed: #{e.message}"
    raise GitSyncError, "Failed to sync changes to GitHub"
  end

  def readme_content
    "# Data Repository\nThis repository contains data for rails-new.io"
  end

  def repository_description
    "Data repository for rails-new.io"
  end
end
