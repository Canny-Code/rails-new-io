class DeleteIngredientJob < ApplicationJob
  queue_as :default

  def perform(user_id:, ingredient_name:, github_template_path:, local_template_path:)
    user = User.find(user_id)

    DataRepositoryService.new(user: user).delete_ingredient(
      ingredient_name: ingredient_name,
      github_template_path: github_template_path,
      local_template_path: local_template_path,
      repo_name: DataRepositoryService.name_for_environment
    )
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error("Failed to delete ingredient: #{e.message}")
    raise
  rescue StandardError => e
    Rails.logger.error("Unexpected error deleting ingredient: #{e.message}")
    raise
  end
end
