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
#  snippets         :json
#  template_content :text             not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  created_by_id    :integer          not null
#  page_id          :integer
#
# Indexes
#
#  index_ingredients_on_created_by_id  (created_by_id)
#  index_ingredients_on_name_scope     (name,created_by_id,page_id,category) UNIQUE
#  index_ingredients_on_page_id        (page_id)
#
# Foreign Keys
#
#  created_by_id  (created_by_id => users.id)
#  page_id        (page_id => pages.id)
#
# frozen_string_literal: true

class Ingredient < ApplicationRecord
  class InvalidConfigurationError < StandardError; end
  include GitBackedModel

  has_one_attached :before_screenshot
  has_one_attached :after_screenshot

  belongs_to :created_by, class_name: "User"
  belongs_to :page, optional: true
  has_many :recipe_ingredients, dependent: :delete_all
  has_many :recipes, through: :recipe_ingredients
  has_many :recipe_changes, dependent: :delete_all
  has_one :custom_ingredient_checkbox, class_name: "Element::CustomIngredientCheckbox", dependent: :destroy

  validates :name, presence: true, uniqueness: { scope: [ :created_by_id, :page_id, :category ] }
  validates :template_content, presence: true
  validates :category, presence: true

  before_destroy :cleanup_ui_elements
  after_update :update_ui_elements, if: :ui_relevant_attributes_changed?
  before_save :process_snippets
  after_save :handle_railsnewio_page_group, if: :should_handle_railsnewio_page_group?

  serialize :conflicts_with, coder: YAML
  serialize :requires, coder: YAML
  serialize :configures_with, coder: YAML

  attr_writer :new_snippets

  def new_snippets
    @new_snippets ||= []
  end

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

  def to_commit_message
    <<~COMMIT_MESSAGE
    * #{name} (#{AppDomain.url}/ingredients/#{id})

      #{description}

    COMMIT_MESSAGE
  end

  def template_with_interpolated_snippets
    return template_content if snippets.blank? || template_content.blank?

    template_content.tap do |content|
      snippets.each_with_index do |snippet, index|
        placeholder = "{{#{index + 1}}}"
        content.gsub!(placeholder, to_literal(snippet, index))
        if content =~ /SNIPPET_#{index+1}\s*,/
          # First move the comma to the opening marker
          content.gsub!(/<<~SNIPPET_#{index+1}/, "<<~SNIPPET_#{index+1},")
          # Then remove any comma after the closing marker, preserving whitespace
          content.gsub!(/^(\s*)SNIPPET_#{index+1}\s*,\s*(\S)/, "\\1SNIPPET_#{index+1}\n\\2")
        end
      end
    end.chomp
  end


  private

  def cleanup_ui_elements
    IngredientUiDestroyer.call(self)
  end

  def update_ui_elements
    IngredientUiUpdater.call(self)
  end

  def ui_relevant_attributes_changed?
    saved_changes.keys.any? { |attr| %w[name description category].include?(attr) }
  end

  def process_snippets
    return if new_snippets.blank?

    self.snippets = new_snippets.compact_blank
  end

  def to_literal(snippet, index)
    if snippet.include?("\n")
      if snippet.start_with?("<<")
        snippet
      else
        <<~SNIPPET
        <<~SNIPPET_#{index+1}
        #{snippet}
        SNIPPET_#{index+1}
        SNIPPET
      end
    else
      if snippet.start_with?("'") || snippet.start_with?('"')
        snippet
      else
        snippet.include?('"') ? "'#{snippet}'" : "\"#{snippet}\""
      end
    end
  end

  def should_handle_railsnewio_page_group?
    created_by.github_username == "rails-new-io" &&
      page_id.present? &&
      page.title != "Your Custom Ingredients" &&
      saved_change_to_page_id?
  end

  def handle_railsnewio_page_group
    IngredientUiCreator.call(self, page_title: page.title)
  end
end
