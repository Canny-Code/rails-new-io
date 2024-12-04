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
require "test_helper"

class RecipeIngredientTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
