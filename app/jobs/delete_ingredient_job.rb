class DeleteIngredientJob < ApplicationJob
  queue_as :default

  def perform(ingredient_id:, user_id:)
    ingredient = Ingredient.find(ingredient_id)
    user = User.find(user_id)

    data_repository = DataRepositoryService.new(user: user)

    data_repository.delete_ingredient(
      ingredient_name: ingredient.name,
      github_template_path: data_repository.github_template_path(ingredient),
      loca_template_path: data_repository.template_path(ingredient),
      repo_name: DataRepositoryService.name_for_environment
    )

    ingredient.destroy
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error("Failed to delete ingredient: #{e.message}")
    raise
  rescue StandardError => e
    Rails.logger.error("Unexpected error deleting ingredient: #{e.message}")
    raise
  end
end
