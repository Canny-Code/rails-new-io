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

    begin
      create_repository(
        repo_name: repo_name,
        description: "Repository created via railsnew.io",
        auto_init: true,
        private: false
      )

      create_initial_structure(repo_name)
    rescue RepositoryExistsError
      begin
        create_initial_structure(repo_name)
      rescue StandardError => e
        # Continue anyway as the repository might already have the structure
      end
    rescue StandardError => e
      raise Error, "Failed to initialize repository: #{e.message}"
    end
  end

  def write_ingredient(ingredient, repo_name:)
    tree_items = []

    # Create ingredient template file
    template_content = ingredient.template_content

    tree_items << {
      path: github_template_path(ingredient),
      mode: "100644",
      type: "blob",
      content: template_content
    }

    begin
      puts "DEBUG: Attempting to write template to path: #{template_path(ingredient)}"
      puts "DEBUG: Template content length: #{template_content.length}"
      puts "DEBUG: Template content empty? #{template_content.empty?}"
      puts "DEBUG: Template content encoding: #{template_content.encoding}"
      puts "DEBUG: Template content first 100 chars: #{template_content[0..100]}"
      puts "DEBUG: Directory exists? #{File.directory?(File.dirname(template_path(ingredient)))}"
      puts "DEBUG: Directory permissions: #{File.stat(File.dirname(template_path(ingredient))).mode.to_s(8)}"
      puts "DEBUG: About to call File.write..."
      result = File.write(template_path(ingredient), template_content)
      puts "DEBUG: File.write returned: #{result}"
      puts "DEBUG: File exists after write? #{File.exist?(template_path(ingredient))}"
      puts "DEBUG: File size after write: #{File.size(template_path(ingredient))}" if File.exist?(template_path(ingredient))
      puts "DEBUG: File written successfully"
    rescue StandardError => e
      puts "DEBUG: Error writing file: #{e.message}"
      puts "DEBUG: Error class: #{e.class}"
      puts "DEBUG: Error backtrace: #{e.backtrace.join("\n")}"
      raise Error, "Failed to write ingredient template to local filesystem: #{e.message}"
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

  def github_template_path(ingredient)
    File.join("ingredients", ingredient.name, "template.rb")
  end

  def template_path(ingredient)
    repo_name = self.class.name_for_environment
    path = Rails.root.join("tmp", repo_name, "ingredients", ingredient.created_by.id.to_s, ingredient.name, "template.rb")

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
