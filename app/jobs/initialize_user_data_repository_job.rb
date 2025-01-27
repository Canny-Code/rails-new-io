class InitializeUserDataRepositoryJob < ApplicationJob
  queue_as :default

  def perform(user_id)
    Rails.logger.info("Starting InitializeUserDataRepositoryJob for user_id: #{user_id}")

    user = User.find_by(id: user_id)
    unless user
      Rails.logger.error("User not found with id: #{user_id}")
      return
    end

    Rails.logger.info("Creating data repository for user: #{user.github_username}")
    data_repository = DataRepositoryService.new(user: user)

    data_repository.initialize_repository
    Rails.logger.info("Data repository creation completed")
  rescue StandardError => e
    Rails.logger.error("Failed to initialize user data repository: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    raise
  end
end
