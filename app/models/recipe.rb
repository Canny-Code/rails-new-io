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
#  ui_state        :json
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
  end

  def remove_ingredient!(ingredient)
    transaction do
      recipe_ingredients.find_by!(ingredient: ingredient).destroy
      reorder_positions
    end
  end

  def reorder_ingredients!(new_order)
    transaction do
      recipe_ingredients.each do |ri|
        ri.update!(position: new_order.index(ri.ingredient_id))
      end
    end
  end

  def self.find_duplicate(user_id, cli_flags, ingredient_ids = nil)
    # A recipe is a duplicate if it has:
    # 1. The same cli_flags AND
    # 2. The same ingredients (or both have no ingredients)

    if ingredient_ids.nil?
      Recipe.joins(<<~SQL)
        LEFT JOIN (
          SELECT recipe_id,
                 COUNT(*) as ingredient_count,
                 GROUP_CONCAT(ingredient_id ORDER BY ingredient_id) as ingredient_list
          FROM recipe_ingredients
          GROUP BY recipe_id
        ) AS rig ON rig.recipe_id = recipes.id
      SQL
      .where(cli_flags: cli_flags)
      .where(created_by_id: user_id)
      .where(<<~SQL)
        (
          COALESCE(rig.ingredient_count, 0) = 0
          OR EXISTS (
            SELECT 1
            FROM recipes r2
            LEFT JOIN (
              SELECT recipe_id,
                     COUNT(*) as ingredient_count,
                     GROUP_CONCAT(ingredient_id ORDER BY ingredient_id) as ingredient_list
              FROM recipe_ingredients
              GROUP BY recipe_id
            ) AS rig2 ON rig2.recipe_id = r2.id
            WHERE r2.cli_flags = recipes.cli_flags
            AND r2.id != recipes.id
            AND COALESCE(rig.ingredient_count, 0) > 0
            AND COALESCE(rig2.ingredient_count, 0) > 0
            AND COALESCE(rig.ingredient_list, '') = COALESCE(rig2.ingredient_list, '')
          )
        )
      SQL
      .order(:id)
      .first
    else
      Recipe.joins(<<~SQL)
        LEFT JOIN (
          SELECT recipe_id,
                 COUNT(*) as ingredient_count
          FROM recipe_ingredients
          GROUP BY recipe_id
        ) AS rig ON rig.recipe_id = recipes.id
      SQL
      .where(cli_flags: cli_flags)
      .where(created_by_id: user_id)
      .where("COALESCE(rig.ingredient_count, 0) = ?", ingredient_ids.size)
      .where(RecipeIngredient.where("recipe_ingredients.recipe_id = recipes.id")
                            .where.not(ingredient_id: ingredient_ids)
                            .arel.exists.not)
      .order(:id)
      .first
    end
  end

  def to_yaml
    {
      name: name,
      description: description,
      cli_flags: cli_flags,
      rails_version: rails_version,
      ruby_version: ruby_version,
      ingredients: recipe_ingredients.order(:position).map { |ri|
        {
          name: ri.ingredient.name,
          position: ri.position,
          configuration: ri.configuration
        }
      }
    }.to_yaml
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
