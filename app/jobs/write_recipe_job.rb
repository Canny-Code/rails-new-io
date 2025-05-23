class WriteRecipeJob < ApplicationJob
  queue_as :default

  def perform(recipe_id:, user_id:)
    user = User.find(user_id)
    recipe = Recipe.find(recipe_id)

    data_repository = DataRepositoryService.new(user: user)
    data_repository.write_recipe(recipe, repo_name: DataRepositoryService.name_for_environment)
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error("Failed to write recipe: #{e.message}")
    raise
  rescue StandardError => e
    Rails.logger.error("Unexpected error writing recipe: #{e.message}")
    raise
  end
end
