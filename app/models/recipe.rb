# == Schema Information
#
# Table name: recipes
#
#  id              :integer          not null, primary key
#  cli_flags       :string
#  description     :text
#  head_commit_sha :string
#  name            :string           not null
#  rails_version   :string
#  ruby_version    :string
#  status          :string           default("draft")
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  created_by_id   :integer          not null
#
# Indexes
#
#  index_recipes_on_created_by_id  (created_by_id)
#
# Foreign Keys
#
#  created_by_id  (created_by_id => users.id)
#
class Recipe < ApplicationRecord
  include GitBackedModel

  class IncompatibleIngredientError < StandardError; end

  belongs_to :created_by, class_name: "User"
  has_many :generated_apps, dependent: :destroy
  has_many :recipe_ingredients, -> { order(position: :asc) }, dependent: :destroy
  has_many :ingredients, through: :recipe_ingredients
  has_many :commits, as: :versioned, dependent: :destroy
  has_many :recipe_changes, dependent: :destroy

  validates :name, presence: true
  validates :status, inclusion: { in: %w[draft published archived] }

  def add_ingredient!(ingredient, configuration = {})
    transaction do
      raise IncompatibleIngredientError unless ingredient_compatible?(ingredient)

      recipe_ingredients.create!(
        ingredient: ingredient,
        position: next_position,
        configuration: configuration
      )

      commit!("Added ingredient: #{ingredient.name}")
    end
  end

  def remove_ingredient!(ingredient)
    transaction do
      recipe_ingredients.find_by!(ingredient: ingredient).destroy
      reorder_positions
      commit!("Removed ingredient: #{ingredient.name}")
    end
  end

  def reorder_ingredients!(new_order)
    transaction do
      recipe_ingredients.each do |ri|
        ri.update!(position: new_order.index(ri.ingredient_id))
      end
      commit!("Reordered ingredients")
    end
  end

  def self.find_duplicate(cli_flags)
    # For now, we only check cli_flags. In the future, when we implement
    # ingredients, we should also check for matching ingredients
    where(cli_flags: cli_flags).first
  end

  private

  def ingredient_compatible?(new_ingredient)
    ingredients.all? { |i| i.compatible_with?(new_ingredient) } &&
      new_ingredient.dependencies_satisfied?(self)
  end

  def next_position
    recipe_ingredients.maximum(:position).to_i + 1
  end

  def reorder_positions
    recipe_ingredients.order(:position).each.with_index(1) do |ri, index|
      ri.update_column(:position, index)
    end
  end
end
