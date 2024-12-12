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

  def compatible_with?(other)
    !conflicts_with.include?(other.name)
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
        next if value.nil? && !validator[:required]
        if validator[:values]
          unless validator[:values].include?(value)
            raise InvalidConfigurationError, "Invalid value for #{key}: #{value}. Must be one of: #{validator[:values].join(', ')}"
          end
        end
      else
        next if value.nil? && !validator.required?
        unless validator.call(value)
          raise InvalidConfigurationError, "Invalid value for #{key}: #{value}"
        end
      end
    end

    # Process template with configuration
    ERB.new(template_content).result_with_hash(configuration.symbolize_keys)
  end
end
