# app/services/github_repository_service.rb
class GithubRepositoryService
  class Error < StandardError; end
  class RepositoryExistsError < Error; end
  class ApiError < Error; end

  def initialize(user)
    @user = user
    @max_retries = 3
    @logger = Rails.logger
  end

  def create_repository(name)
    if repository_exists?(name)
      raise RepositoryExistsError, "Repository '#{name}' already exists"
    end

    with_error_handling do
      log_action("Creating repository: #{name} for user: #{@user.github_username}")

      options = {
        private: false,
        auto_init: false,
        description: "Repository created via railsnew.io"
      }

      response = client.create_repository(name, options)

      @user.repositories.create!(
        name: name,
        github_url: response.html_url
      )

      response
    end
  end

  private

  def repository_exists?(name)
    with_error_handling do
      client.repository?("#{@user.github_username}/#{name}")
    end
  rescue GithubRepositoryService::ApiError => e
    raise # Re-raise API errors
  rescue StandardError => e
    false # Assume repository doesn't exist if we can't check
  end

  def client
    @client ||= Octokit::Client.new(
      access_token: @user.github_token,
      auto_paginate: true
    )
  end

  def with_error_handling
    retries = 0
    begin
      yield
    rescue Octokit::TooManyRequests => e
      log_error("Rate limit exceeded: #{e.message}")
      reset_time = client.rate_limit.resets_at
      sleep_time = [ reset_time - Time.now, 0 ].max
      sleep(sleep_time)
      retry if (retries += 1) <= @max_retries
      raise ApiError, "Rate limit exceeded and retry attempts exhausted"
    rescue Octokit::Error => e
      log_error("GitHub API error: #{e.message}")
      retry if (retries += 1) <= @max_retries
      raise ApiError, "GitHub API error: #{e.message}"
    rescue StandardError => e
      log_error("Unexpected error: #{e.message}")
      raise Error, "Unexpected error: #{e.message}"
    end
  end

  def log_action(message)
    @logger.info("[GithubRepositoryService] #{message}")
  end

  def log_error(message)
    @logger.error("[GithubRepositoryService] #{message}")
  end
end
