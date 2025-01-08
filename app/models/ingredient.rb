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
#  index_ingredients_on_created_by_id           (created_by_id)
#  index_ingredients_on_name_and_created_by_id  (name,created_by_id) UNIQUE
#
# Foreign Keys
#
#  created_by_id  (created_by_id => users.id)
#
class Ingredient < ApplicationRecord
  class InvalidConfigurationError < StandardError; end
  include GitBackedModel

  belongs_to :created_by, class_name: "User"
  has_many :recipe_ingredients, dependent: :delete_all
  has_many :recipes, through: :recipe_ingredients
  has_many :recipe_changes, dependent: :delete_all

  validates :name, presence: true, uniqueness: { scope: :created_by_id }
  validates :template_content, presence: true

  before_destroy :cleanup_ui_elements

  serialize :conflicts_with, coder: YAML
  serialize :requires, coder: YAML
  serialize :configures_with, coder: YAML

  def compatible_with?(other_ingredient)
    (conflicts_with & [ other_ingredient.name ]).empty?
  end

  def dependencies_satisfied?(recipe)
    requires.all? { |dep| recipe.ingredients.any? { |i| i.name == dep } }
  end

  def configuration_for(configuration)
    # Validate configuration against configures_with schema
    configures_with.each do |key, validator|
      value = configuration[key.to_s]

      case validator
      when Array
        unless validator.include?(value)
          raise InvalidConfigurationError, "Invalid value for #{key}: #{value}. Must be one of: #{validator.join(', ')}"
        end
      when Hash
        # Check required first
        if validator[:required] && value.nil?
          raise InvalidConfigurationError, "#{key} is required"
        end

        next if value.nil? && !validator[:required]

        if validator[:values]
          unless validator[:values].include?(value)
            raise InvalidConfigurationError, "Invalid value for #{key}: #{value}. Must be one of: #{validator[:values].join(', ')}"
          end
        elsif validator[:validate] == "positive_integer"
          unless value.to_i.positive?
            raise InvalidConfigurationError, "Invalid value for #{key}: #{value}. Must be a positive integer."
          end
        end
      end
    end

    # Process template with configuration
    ERB.new(template_content).result_with_hash(configuration.symbolize_keys)
  end

  private

  def cleanup_ui_elements
    IngredientUiDestroyer.call(self)
  end
end
