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

    response = create_repository(
      repo_name: repo_name,
      description: "Repository created via railsnew.io",
      auto_init: false
    )

    create_initial_structure(repo_name)
    response
  rescue RepositoryExistsError
    # Repository already exists, that's fine
    nil
  end

  def write_ingredient(ingredient, repo_name:)
    tree_items = []

    # Create ingredient template file
    tree_items << {
      path: "ingredients/#{ingredient.name}/template.rb",
      mode: "100644",
      type: "blob",
      content: ingredient.template_content
    }

    commit_changes(
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
      message: "Update recipe: #{recipe.name}",
      tree_items: tree_items
    )
  end

  def commit_changes(message:, tree_items:)
    super(
      repo_name: self.class.name_for_environment,
      message: message,
      tree_items: tree_items
    )
  end

  def template_path(ingredient)
    Rails.root.join("tmp", "ingredients", ingredient.name, "template.rb").to_s
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
      message: "Initialize repository structure",
      tree_items: tree_items
    )
  end

  def readme_content
    "# Data Repository\nThis repository contains data for railsnew.io"
  end
end
