# app/services/github_repository_service.rb
class GithubRepositoryService
  class Error < StandardError; end
  class RepositoryExistsError < Error; end
  class ApiError < Error; end

  def initialize(generated_app)
    @generated_app = generated_app
    @user = generated_app.user
    @max_retries = 3
    @logger = AppGeneration::Logger.new(generated_app)
  end

  def create_repository(repo_name:)
    if repository_exists?(repo_name)
      @logger.error("Repository '#{repo_name}' already exists")
      raise RepositoryExistsError, "Repository '#{repo_name}' already exists"
    end

    @generated_app.create_github_repo!
    @logger.info("Creating repository: #{repo_name}", { username: @user.github_username })

    with_error_handling do
      options = {
        private: false,
        auto_init: false,
        description: "Repository created via railsnew.io"
      }

      response = client.create_repository(repo_name, **options)

      @generated_app.update!(
        github_repo_name: repo_name,
        github_repo_url: response.html_url
      )

      @logger.info("GitHub repo #{repo_name} created successfully", { url: response.html_url })
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
      @logger.warn("Rate limit exceeded, waiting for reset", {
        reset_time: client.rate_limit.resets_at,
        retry_count: retries
      })

      reset_time = client.rate_limit.resets_at
      sleep_time = [ reset_time - Time.now, 0 ].max
      sleep(sleep_time)

      retry if (retries += 1) <= @max_retries

      @logger.error("Rate limit exceeded and retry attempts exhausted")
      raise ApiError, "Rate limit exceeded and retry attempts exhausted"
    rescue Octokit::Error => e
      @logger.error("GitHub API error", { error: e.message, retry_count: retries })

      retry if (retries += 1) <= @max_retries
      raise ApiError, "GitHub API error: #{e.message}"
    rescue StandardError => e
      @logger.error("Unexpected error", { error: e.message })
      raise Error, "Unexpected error: #{e.message}"
    end
  end
end
