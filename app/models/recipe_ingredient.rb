# == Schema Information
#
# Table name: recipe_ingredients
#
#  id            :integer          not null, primary key
#  applied_at    :datetime
#  configuration :json
#  position      :integer          not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  ingredient_id :integer          not null
#  recipe_id     :integer          not null
#
# Indexes
#
#  index_recipe_ingredients_on_ingredient_id           (ingredient_id)
#  index_recipe_ingredients_on_recipe_id               (recipe_id)
#  index_recipe_ingredients_on_recipe_id_and_position  (recipe_id,position) UNIQUE
#
# Foreign Keys
#
#  ingredient_id  (ingredient_id => ingredients.id)
#  recipe_id      (recipe_id => recipes.id)
#
class RecipeIngredient < ApplicationRecord
  belongs_to :recipe
  belongs_to :ingredient

  validates :position, presence: true, uniqueness: { scope: :recipe_id }
  # validates :configuration, presence: true

  after_create -> { recipe.touch }
  after_destroy -> { recipe.touch }
  after_update -> { recipe.touch }

  def to_git_format
    {
      ingredient_name: ingredient.name,
      position: position,
      configuration: configuration,
      applied_at: applied_at&.iso8601
    }
  end

  def apply!
    return if applied_at.present?

    transaction do
      content = ingredient.configuration_for(configuration)
      # Apply the template here
      update!(applied_at: Time.current)
    end
  end
end
