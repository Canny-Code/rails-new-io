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

  attr_reader :user, :repo_name, :source_path, :cleanup_after_push

  def initialize(user_or_options, source_path = nil, cleanup_after_push = false)
    if user_or_options.is_a?(Hash)
      @user = user_or_options[:user]
      @source_path = user_or_options[:source_path]
      @cleanup_after_push = user_or_options[:cleanup_after_push] || false
    else
      @user = user_or_options
      @source_path = source_path
      @cleanup_after_push = cleanup_after_push
    end

    @repo_name = self.class.name_for_environment
  end

  def template_path(ingredient = nil)
    base_path = Rails.root.join("tmp/git_repos/#{user.id}/#{repo_name}")
    return base_path unless ingredient

    File.join(base_path, "ingredients", ingredient.name, "template.rb")
  end

  def repo_path
    template_path
  end

  def write_model(model)
    case model
    when Ingredient
      write_ingredient(model)
    when Recipe
      write_recipe(model)
    else
      raise ArgumentError, "Unsupported model type: #{model.class}"
    end
  end

  def create_repository
    Rails.logger.info("Checking if remote repository exists...")
    return if remote_repo_exists?

    Rails.logger.info("Creating GitHub repository...")
    create_github_repo

    Rails.logger.info("Creating initial structure...")
    create_initial_structure
  end

  protected

  def repository_description
    "Data repository for railsnew.io"
  end

  def readme_content
    "# Data Repository\nThis repository contains data for railsnew.io"
  end

  private

  def remote_repo_exists?
    github_client.repository?("#{user.github_username}/#{repo_name}")
  rescue Octokit::Error => e
    Rails.logger.error("Failed to check GitHub repository: #{e.message}")
    false
  end

  def create_github_repo
    github_client.create_repository(
      repo_name,
      private: false,
      description: repository_description,
      auto_init: true,
      default_branch: "main"
    )
  rescue Octokit::Error => e
    Rails.logger.error("Failed to create GitHub repository: #{e.message}")
    raise GitError, "Failed to create GitHub repository: #{e.message}"
  end

  def create_initial_structure
    # Get the current tree
    ref = github_client.ref("#{user.github_username}/#{repo_name}", "heads/main")
    commit = github_client.commit("#{user.github_username}/#{repo_name}", ref.object.sha)
    base_tree = commit.commit.tree

    # Create blobs for initial structure
    blobs = []

    # Add README if it doesn't exist
    readme_blob = github_client.create_blob(
      "#{user.github_username}/#{repo_name}",
      readme_content,
      "utf-8"
    )
    blobs << { path: "README.md", mode: "100644", type: "blob", sha: readme_blob }

    # Create ingredients directory with .keep file
    keep_blob = github_client.create_blob(
      "#{user.github_username}/#{repo_name}",
      "",
      "utf-8"
    )
    blobs << { path: "ingredients/.keep", mode: "100644", type: "blob", sha: keep_blob }

    # Create recipes directory with .keep file
    blobs << { path: "recipes/.keep", mode: "100644", type: "blob", sha: keep_blob }

    # Create the tree
    tree = github_client.create_tree(
      "#{user.github_username}/#{repo_name}",
      blobs,
      base_tree: base_tree.sha
    )

    # Create the commit
    commit = github_client.create_commit(
      "#{user.github_username}/#{repo_name}",
      "Initialize repository structure",
      tree.sha,
      ref.object.sha,
      author: {
        name: user.name || user.github_username,
        email: user.email || "#{user.github_username}@users.noreply.github.com"
      }
    )

    # Update the reference
    github_client.update_ref(
      "#{user.github_username}/#{repo_name}",
      "heads/main",
      commit.sha
    )
  rescue Octokit::Error => e
    Rails.logger.error("Failed to create initial structure: #{e.message}")
    raise GitError, "Failed to create initial structure: #{e.message}"
  end

  def github_client
    @github_client ||= Octokit::Client.new(access_token: user.github_token)
  end

  class GitError < StandardError; end
end
