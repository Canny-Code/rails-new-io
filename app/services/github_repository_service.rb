module GithubRepositoryErrors
  class Error < StandardError; end
  class RepositoryExistsError < Error; end
  class ApiError < Error; end
end

class GithubRepositoryService
  include GithubRepositoryErrors

  attr_reader :user, :logger

  def initialize(user:, logger: Rails.logger)
    @user = user
    @max_retries = 3
    @logger = logger
  end

  def create_repository(repo_name:, description: "Repository created via railsnew.io", private: false, auto_init: true)
    # Check if repository exists
    if repository_exists?(repo_name)
      logger.error("Repository '#{repo_name}' already exists")
      raise RepositoryExistsError, "Repository '#{repo_name}' already exists"
    end

    with_error_handling do
      # Create new repository with main as default branch
      client.create_repository(repo_name,
        private: private,
        auto_init: auto_init,
        description: description,
        default_branch: "main"
      )
    end
  end

  def repository_exists?(name)
    with_error_handling do
      client.repository?("#{user.github_username}/#{name}")
    end
  end

  def commit_changes(repo_name:, message:, tree_items:, base_tree_sha: nil)
    with_error_handling do
      repo_full_name = "#{user.github_username}/#{repo_name}"

      # Get current tree SHA if not provided
      if base_tree_sha.nil?
        begin
          ref = client.ref(repo_full_name, "heads/main")
          commit = client.commit(repo_full_name, ref.object.sha)
          base_tree_sha = commit.commit.tree.sha
        rescue Octokit::NotFound => e
          raise ApiError, "Main branch not found. This should never happen as we always create repositories with main branch."
        end
      end

      # Create new tree
      new_tree = client.create_tree(
        repo_full_name,
        tree_items,
        base_tree: base_tree_sha
      )

      # Get the latest commit SHA to use as parent
      latest_commit_sha = client.ref(repo_full_name, "heads/main").object.sha

      # Create commit
      new_commit = client.create_commit(
        repo_full_name,
        message,
        new_tree.sha,
        latest_commit_sha,
        author: commit_author
      )

      # Update reference
      client.update_ref(
        repo_full_name,
        "heads/main",
        new_commit.sha
      )

      new_commit
    end
  end

  protected

  def client
    @client ||= Octokit::Client.new(
      access_token: user.github_token,
      auto_paginate: true
    )
  end

  def commit_author
    {
      name: user.name || user.github_username,
      email: user.email || "#{user.github_username}@users.noreply.github.com"
    }
  end

  def with_error_handling
    retries = 0
    begin
      yield
    rescue Octokit::TooManyRequests => e
      # Get rate limit info once
      rate_limit = client.rate_limit
      reset_time = rate_limit.resets_at
      sleep_time = [ reset_time - Time.now, 0 ].max

      logger.warn("Rate limit exceeded, waiting for reset. Reset time: #{reset_time}, retry: #{retries}")

      retries += 1
      if retries < @max_retries
        sleep sleep_time
        retry
      end

      logger.error("Rate limit exceeded and retry attempts exhausted")
      raise ApiError, "Rate limit exceeded and retry attempts exhausted"
    rescue Octokit::Error => e
      logger.error("GitHub API error: #{e.message}")

      retries += 1
      if retries < @max_retries
        retry
      end
      raise ApiError, "GitHub API error: #{e.message}"
    rescue StandardError => e
      raise Error, "Unexpected error: #{e.message}"
    end
  end
end
