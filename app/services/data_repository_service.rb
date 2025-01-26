# app/services/data_repository_service.rb
class DataRepositoryService < GithubRepositoryService
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

  def initialize_repository
    repo_name = self.class.name_for_environment
    repo_full_name = "#{user.github_username}/#{repo_name}"

    begin
      # Create repository with auto_init to get a base commit
      response = create_repository(
        repo_name: repo_name,
        description: "Repository created via railsnew.io",
        auto_init: true,
        private: false
      )

      # Give Github a moment to create the initial commit
      sleep 2

      create_initial_structure(repo_name)
      response
    rescue RepositoryExistsError
      begin
        create_initial_structure(repo_name)
      rescue StandardError => e
        # Continue anyway as the repository might already have the structure
      end
      # Return a GitRepo object for existing repository
      GitTestHelper::GitRepo.new(html_url: "https://github.com/#{repo_full_name}")
    rescue StandardError => e
      raise Error, "Failed to initialize repository: #{e.message}"
    end
  end

  def write_ingredient(ingredient, repo_name:)
    tree_items = []

    # Create ingredient template file
    template_content = ingredient.template_content
    tree_items << {
      path: "ingredients/#{ingredient.name}/template.rb",
      mode: "100644",
      type: "blob",
      content: template_content
    }

    # Write to local filesystem
    local_path = template_path(ingredient)
    begin
      File.write(local_path, template_content)
    rescue StandardError => e
      raise
    end

    commit_changes(
      repo_name: repo_name,
      message: "Update ingredient: #{ingredient.name}",
      tree_items: tree_items
    )
  end

  def write_recipe(recipe, repo_name:)
    tree_items = []

    # Create recipe file
    tree_items << {
      path: "recipes/#{recipe.name}.yml",
      mode: "100644",
      type: "blob",
      content: recipe.to_yaml
    }

    commit_changes(
      repo_name: repo_name,
      message: "Update recipe: #{recipe.name}",
      tree_items: tree_items
    )
  end

  def commit_changes(message:, tree_items:, repo_name: nil)
    super(
      repo_name: repo_name || self.class.name_for_environment,
      message: message,
      tree_items: tree_items
    )
  end

  def template_path(ingredient)
    repo_name = self.class.name_for_environment
    path = Rails.root.join("tmp", repo_name, "ingredients", ingredient.name, "template.rb")

    # Ensure directory exists
    FileUtils.mkdir_p(path.dirname)

    path.to_s
  end

  private

  def create_initial_structure(repo_name)
    tree_items = []

    # Add README
    tree_items << {
      path: "README.md",
      mode: "100644",
      type: "blob",
      content: readme_content
    }

    # Create ingredients directory with .keep file
    tree_items << {
      path: "ingredients/.keep",
      mode: "100644",
      type: "blob",
      content: ""
    }

    # Create recipes directory with .keep file
    tree_items << {
      path: "recipes/.keep",
      mode: "100644",
      type: "blob",
      content: ""
    }

    commit_changes(
      repo_name: repo_name,
      message: "Initialize repository structure",
      tree_items: tree_items
    )
  end

  def readme_content
    "# Data Repository\nThis repository contains data for railsnew.io"
  end
end
