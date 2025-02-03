class WriteIngredientJob < ApplicationJob
  queue_as :default

  def perform(ingredient_id:, user_id:)
    ingredient = Ingredient.find(ingredient_id)
    user = User.find(user_id)

    data_repository = DataRepositoryService.new(user: user)
    data_repository.write_ingredient(ingredient, repo_name: DataRepositoryService.name_for_environment)
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error("Failed to write ingredient: #{e.message}")
    raise
  rescue StandardError => e
    Rails.logger.error("Unexpected error writing ingredient: #{e.message}")
    raise
  end
end
