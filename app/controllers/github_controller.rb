class GithubController < ApplicationController
  before_action :authenticate_user!

  def check_name
    validator = GithubRepositoryNameValidator.new(
      params[:name],
      current_user.github_username
    )
    begin
      render json: { available: validator.repo_can_be_created? }
    rescue Octokit::Unauthorized, Octokit::Forbidden => e
      Rails.logger.error("GitHub authentication error: #{e.message}")
      render json: { error: "GitHub authentication failed" }, status: :unauthorized
    rescue => e
      Rails.logger.error("GitHub validation error: #{e.message}")
      render json: { error: "Could not validate repository name" }, status: :unprocessable_entity
    end
  end
end
