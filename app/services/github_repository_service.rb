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

  def create_repository(repo_name:, description: "Repository created via railsnew.io", private: false, auto_init: true)
    puts "\nDEBUG: [create_repository] Starting with repo_name: #{repo_name}"
    # First check if repository exists
    puts "DEBUG: [create_repository] Checking if repository exists"
    exists = begin
      puts "DEBUG: [create_repository] Calling repository_exists?"
      result = repository_exists?(repo_name)
      puts "DEBUG: [create_repository] repository_exists? returned: #{result}"
      result
    rescue GithubRepositoryService::ApiError => e
      puts "DEBUG: [create_repository] Caught ApiError: #{e.class} - #{e.message}"
      puts "DEBUG: [create_repository] ApiError backtrace:\n#{e.backtrace.join("\n")}"
      raise # Re-raise API errors immediately
    rescue => e
      puts "DEBUG: [create_repository] Caught unexpected error: #{e.class} - #{e.message}"
      puts "DEBUG: [create_repository] Error backtrace:\n#{e.backtrace.join("\n")}"
      raise
    end

    if exists
      puts "DEBUG: [create_repository] Repository exists, raising error"
      logger.error("Repository '#{repo_name}' already exists")
      raise RepositoryExistsError, "Repository '#{repo_name}' already exists"
    end

    puts "DEBUG: [create_repository] Repository doesn't exist, creating it"
    with_error_handling do
      puts "DEBUG: [create_repository] Calling GitHub API to create repository"
      client.create_repository(repo_name,
        private: private,
        auto_init: auto_init,
        description: description,
        default_branch: "main"
      )
    end
  end

  def repository_exists?(name)
    puts "\nDEBUG: [repository_exists?] Starting check for: #{name}"
    puts "DEBUG: [repository_exists?] Full repo name: #{user.github_username}/#{name}"
    with_error_handling do
      puts "DEBUG: [repository_exists?] Calling client.repository?"
      result = client.repository?("#{user.github_username}/#{name}")
      puts "DEBUG: [repository_exists?] client.repository? returned: #{result}"
      result
    end
  rescue GithubRepositoryService::ApiError => e
    puts "DEBUG: [repository_exists?] Caught ApiError: #{e.class} - #{e.message}"
    puts "DEBUG: [repository_exists?] ApiError backtrace:\n#{e.backtrace.join("\n")}"
    raise # Re-raise API errors
  rescue StandardError => e
    puts "DEBUG: [repository_exists?] Caught unexpected error: #{e.class} - #{e.message}"
    puts "DEBUG: [repository_exists?] Error backtrace:\n#{e.backtrace.join("\n")}"
    raise # Don't swallow unexpected errors
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
      puts "DEBUG: [with_error_handling] Attempt #{retries + 1}"
      result = yield
      puts "DEBUG: [with_error_handling] Call succeeded, returning: #{result.inspect}"
      result
    rescue Octokit::TooManyRequests => e
      puts "DEBUG: [with_error_handling] Caught TooManyRequests on attempt #{retries + 1}"
      puts "DEBUG: [with_error_handling] Error details: #{e.inspect}"

      # Get rate limit info once
      rate_limit = client.rate_limit
      reset_time = rate_limit.resets_at
      sleep_time = [ reset_time - Time.now, 0 ].max

      logger.warn("Rate limit exceeded, waiting for reset. Reset time: #{reset_time}, retry: #{retries}")
      puts "DEBUG: [with_error_handling] Would sleep for #{sleep_time} seconds"

      retries += 1
      if retries < @max_retries
        puts "DEBUG: [with_error_handling] Retrying (attempt #{retries + 1})"
        retry
      end

      puts "DEBUG: [with_error_handling] Max retries exceeded, raising ApiError"
      logger.error("Rate limit exceeded and retry attempts exhausted")
      raise ApiError, "Rate limit exceeded and retry attempts exhausted"
    rescue Octokit::Error => e
      puts "DEBUG: [with_error_handling] Caught Octokit::Error on attempt #{retries + 1}: #{e.message}"
      logger.error("GitHub API error: #{e.message}")

      retries += 1
      if retries < @max_retries
        puts "DEBUG: [with_error_handling] Retrying (attempt #{retries + 1})"
        retry
      end
      raise ApiError, "GitHub API error: #{e.message}"
    rescue StandardError => e
      puts "DEBUG: [with_error_handling] Caught unexpected error: #{e.class} - #{e.message}"
      puts "DEBUG: [with_error_handling] Error backtrace:\n#{e.backtrace.join("\n")}"
      raise Error, "Unexpected error: #{e.message}"
    end
  end
end
