# == Schema Information
#
# Table name: ingredients
#
#  id               :integer          not null, primary key
#  category         :string
#  configures_with  :text
#  conflicts_with   :text
#  description      :text
#  name             :string           not null
#  requires         :text
#  template_content :text             not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  created_by_id    :integer          not null
#
# Indexes
#
#  index_ingredients_on_created_by_id  (created_by_id)
#  index_ingredients_on_name           (name) UNIQUE
#
# Foreign Keys
#
#  created_by_id  (created_by_id => users.id)
#
class Ingredient < ApplicationRecord
  include GitBackedModel

  belongs_to :created_by, class_name: "User"
  has_many :recipe_ingredients, dependent: :destroy
  has_many :recipes, through: :recipe_ingredients
  has_many :app_changes, dependent: :destroy

  validates :name, presence: true, uniqueness: true
  validates :template_content, presence: true

  serialize :conflicts_with, coder: YAML
  serialize :requires, coder: YAML
  serialize :configures_with, coder: YAML

  def compatible_with?(other_ingredient)
    !conflicts_with.include?(other_ingredient.name)
  end

  def dependencies_satisfied?(recipe)
    requires.all? { |req| recipe.ingredients.exists?(name: req) }
  end

  def configuration_for(context = {})
    template_content.dup.tap do |content|
      configures_with.each do |ingredient_name, config_proc|
        content.gsub!("{{#{ingredient_name}}}", config_proc.call(context))
      end
    end
  end
end
