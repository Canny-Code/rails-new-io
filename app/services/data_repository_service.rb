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
    puts "DEBUG: Initializing repository: #{repo_name}"
    repo_full_name = "#{user.github_username}/#{repo_name}"

    begin
      # Create repository with auto_init to get a base commit
      response = create_repository(
        repo_name: repo_name,
        description: "Repository created via railsnew.io",
        auto_init: true,
        private: false
      )
      puts "DEBUG: Repository creation response: #{response.inspect}"

      # Give Github a moment to create the initial commit
      sleep 2

      create_initial_structure(repo_name)
      response
    rescue RepositoryExistsError
      puts "DEBUG: Repository already exists, continuing with initialization"
      begin
        create_initial_structure(repo_name)
      rescue StandardError => e
        puts "DEBUG: Error creating initial structure: #{e.message}"
        # Continue anyway as the repository might already have the structure
      end
      # Return a GitRepo object for existing repository
      GitTestHelper::GitRepo.new(html_url: "https://github.com/#{repo_full_name}")
    rescue StandardError => e
      puts "DEBUG: Error during repository initialization: #{e.class} - #{e.message}"
      puts e.backtrace
      raise Error, "Failed to initialize repository: #{e.message}"
    end
  end

  def write_ingredient(ingredient, repo_name:)
    puts "DEBUG: Writing ingredient #{ingredient.name} to repo #{repo_name}"
    puts "DEBUG: Template content: #{ingredient.template_content.inspect}"

    if ingredient.template_content.nil? || ingredient.template_content.empty?
      puts "DEBUG: WARNING - template_content is empty!"
    end

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
    puts "DEBUG: Writing to local path: #{local_path}"
    begin
      File.write(local_path, template_content)
      puts "DEBUG: Successfully wrote file"
      puts "DEBUG: File exists? #{File.exist?(local_path)}"
      puts "DEBUG: File content: #{File.read(local_path)}"
    rescue StandardError => e
      puts "DEBUG: Error writing file: #{e.message}"
      puts "DEBUG: Error backtrace: #{e.backtrace.join("\n")}"
      raise
    end

    commit_changes(
      repo_name: repo_name,
      message: "Update ingredient: #{ingredient.name}",
      tree_items: tree_items
    )
  end

  def write_recipe(recipe, repo_name:)
    puts "DEBUG: Writing recipe #{recipe.name} to repo #{repo_name}"
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
    puts "DEBUG: Committing changes to repo: #{repo_name || self.class.name_for_environment}"
    super(
      repo_name: repo_name || self.class.name_for_environment,
      message: message,
      tree_items: tree_items
    )
  end

  def template_path(ingredient)
    puts "DEBUG: Getting template path for ingredient: #{ingredient.name}"
    repo_name = self.class.name_for_environment
    path = Rails.root.join("tmp", repo_name, "ingredients", ingredient.name, "template.rb")

    # Ensure directory exists
    FileUtils.mkdir_p(path.dirname)

    puts "DEBUG: Template path: #{path}"
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
