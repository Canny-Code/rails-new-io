# app/services/github_repository_service.rb
class GithubRepositoryService
  class Error < StandardError; end
  class RepositoryExistsError < Error; end
  class ApiError < Error; end

  attr_reader :user, :logger

  def initialize(user:, logger: Rails.logger)
    @user = user
    @max_retries = 3
    @logger = logger
  end

  def create_repository(repo_name:, description: nil, private: false, auto_init: true)
    if repository_exists?(repo_name)
      logger.error("Repository '#{repo_name}' already exists")
      raise RepositoryExistsError, "Repository '#{repo_name}' already exists"
    end

    with_error_handling do
      # Just pass everything as a single hash to Octokit
      client.create_repository(repo_name, private: private, auto_init: auto_init, description: description || "Repository created via railsnew.io")
    end
  end

  def repository_exists?(name)
    with_error_handling do
      client.repository?("#{user.github_username}/#{name}")
    end
  rescue GithubRepositoryService::ApiError => e
    raise # Re-raise API errors
  rescue StandardError => e
    false # Assume repository doesn't exist if we can't check
  end

  def commit_changes(repo_name:, message:, tree_items:, base_tree_sha: nil)
    with_error_handling do
      repo_full_name = "#{user.github_username}/#{repo_name}"

      # Get current tree SHA if not provided
      if base_tree_sha.nil?
        ref = client.ref(repo_full_name, "heads/main")
        commit = client.commit(repo_full_name, ref.object.sha)
        base_tree_sha = commit.commit.tree.sha
      end

      # Create new tree
      new_tree = client.create_tree(
        repo_full_name,
        tree_items,
        base_tree: base_tree_sha
      )

      # Create commit
      new_commit = client.create_commit(
        repo_full_name,
        message,
        new_tree.sha,
        base_tree_sha,
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
      logger.warn("Rate limit exceeded, waiting for reset", {
        reset_time: client.rate_limit.resets_at,
        retry_count: retries
      })

      reset_time = client.rate_limit.resets_at
      sleep_time = [ reset_time - Time.now, 0 ].max
      sleep(sleep_time)

      retry if (retries += 1) <= @max_retries

      logger.error("Rate limit exceeded and retry attempts exhausted")
      raise ApiError, "Rate limit exceeded and retry attempts exhausted"
    rescue Octokit::Error => e
      logger.error("GitHub API error", { error: e.message, retry_count: retries })

      retry if (retries += 1) <= @max_retries
      raise ApiError, "GitHub API error: #{e.message}"
 ##   rescue StandardError => e
 ##     raise Error, "Unexpected error: #{e.message}"
    end
  end
end
