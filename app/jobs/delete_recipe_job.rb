class DeleteRecipeJob < ApplicationJob
  queue_as :default

  def perform(user_id:, recipe_name:)
    user = User.find(user_id)

    DataRepositoryService.new(user: user).delete_recipe(
      recipe_name: recipe_name,
      repo_name: DataRepositoryService.name_for_environment
    )
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error("Failed to delete recipe: #{e.message}")
    raise
  rescue StandardError => e
    Rails.logger.error("Unexpected error deleting recipe: #{e.message}")
    raise
  end
end
