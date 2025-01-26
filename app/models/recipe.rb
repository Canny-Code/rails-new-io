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
    end
    sync_to_git
  end

  def remove_ingredient!(ingredient)
    transaction do
      recipe_ingredients.find_by!(ingredient: ingredient).destroy
      reorder_positions
    end
    sync_to_git
  end

  def reorder_ingredients!(new_order)
    transaction do
      recipe_ingredients.each do |ri|
        ri.update!(position: new_order.index(ri.ingredient_id))
      end
    end
    sync_to_git
  end

  def self.find_duplicate(cli_flags, ingredient_ids = nil)
    # A recipe is a duplicate if it has:
    # 1. The same cli_flags AND
    # 2. The same ingredients (or both have no ingredients)
    sql = if ingredient_ids.nil?
      # Original behavior - find a recipe with the same flags and ingredients as another recipe
      <<~SQL
        WITH recipe_ingredients_grouped AS (
          SELECT recipe_id,
                 COUNT(*) as ingredient_count,
                 GROUP_CONCAT(ingredient_id ORDER BY ingredient_id) as ingredient_list
          FROM recipe_ingredients
          GROUP BY recipe_id
        )
        SELECT r.*
        FROM recipes r
        LEFT JOIN recipe_ingredients_grouped rig ON rig.recipe_id = r.id
        WHERE r.cli_flags = ?
        AND (
          COALESCE(rig.ingredient_count, 0) = 0
          OR EXISTS (
            SELECT 1
            FROM recipes r2
            LEFT JOIN recipe_ingredients_grouped rig2 ON rig2.recipe_id = r2.id
            WHERE r2.cli_flags = r.cli_flags
            AND r2.id != r.id
            AND COALESCE(rig.ingredient_count, 0) > 0
            AND COALESCE(rig2.ingredient_count, 0) > 0
            AND COALESCE(rig.ingredient_list, '') = COALESCE(rig2.ingredient_list, '')
          )
        )
        ORDER BY r.id
        LIMIT 1
      SQL
    else
      # New behavior - find a recipe with the same flags and exactly these ingredients
      placeholders = ingredient_ids.map { "?" }.join(",")
      <<~SQL
        WITH recipe_ingredients_grouped AS (
          SELECT recipe_id,
                 COUNT(*) as ingredient_count,
                 GROUP_CONCAT(ingredient_id ORDER BY ingredient_id) as ingredient_list
          FROM recipe_ingredients
          GROUP BY recipe_id
        )
        SELECT r.*
        FROM recipes r
        LEFT JOIN recipe_ingredients_grouped rig ON rig.recipe_id = r.id
        WHERE r.cli_flags = ?
        AND COALESCE(rig.ingredient_count, 0) = ?
        AND NOT EXISTS (
          -- Check that all recipe ingredients are in our list
          SELECT 1
          FROM recipe_ingredients ri
          WHERE ri.recipe_id = r.id
          AND ri.ingredient_id NOT IN (#{placeholders})
        )
        ORDER BY r.id
        LIMIT 1
      SQL
    end

    binds = if ingredient_ids.nil?
      [ cli_flags ]
    else
      [
        cli_flags,
        ingredient_ids.size,
        *ingredient_ids.sort
      ]
    end

    find_by_sql([ sql, *binds ]).first
  end

  private

  def ingredient_compatible?(new_ingredient)
    true
    # ingredients.all? { |i| i.compatible_with?(new_ingredient) } &&
    #   new_ingredient.dependencies_satisfied?(self)
  end

  def next_position
    recipe_ingredients.maximum(:position).to_i + 1
  end

  def reorder_positions
    recipe_ingredients.order(:position).each.with_index(1) do |ri, index|
      ri.update!(position: index)
    end
  end
end
