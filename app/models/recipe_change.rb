# == Schema Information
#
# Table name: recipe_changes
#
#  id            :integer          not null, primary key
#  applied_at    :datetime
#  change_type   :string           not null
#  change_data   :json             not null
#  description   :text
#  error_message :text
#  success       :boolean
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  ingredient_id :integer
#  recipe_id     :integer          not null
#
# Indexes
#
#  index_recipe_changes_on_ingredient_id  (ingredient_id)
#  index_recipe_changes_on_recipe_id      (recipe_id)
#
# Foreign Keys
#
#  ingredient_id  (ingredient_id => ingredients.id)
#  recipe_id      (recipe_id => recipes.id) ON DELETE => cascade
#
class RecipeChange < ApplicationRecord
  belongs_to :recipe
  belongs_to :ingredient, optional: true
  has_many :app_changes, dependent: :nullify

  validates :change_type, presence: true,
    inclusion: { in: %w[add_ingredient remove_ingredient reorder_ingredients update_configuration] }
  validates :change_data, presence: true

  def apply_to_app(app, configuration = {})
    case change_type
    when "add_ingredient"
      ingredient.configuration_for(configuration)
    when "remove_ingredient"
      generate_removal_template(ingredient)
    when "reorder_ingredients"
      generate_reorder_template(change_data["order"])
    when "update_configuration"
      generate_config_update_template(change_data["configuration"])
    else
      raise ArgumentError, "Unknown change type: #{change_type}"
    end
  end

  def apply!
    return if applied_at.present?

    transaction do
      case change_type
      when "add_ingredient"
        recipe.add_ingredient!(ingredient, change_data["configuration"])
      when "remove_ingredient"
        recipe.remove_ingredient!(ingredient)
      when "reorder_ingredients"
        recipe.reorder_ingredients!(change_data["order"])
      when "update_configuration"
        recipe.update!(change_data["configuration"])
      end

      update!(
        applied_at: Time.current,
        success: true
      )
    end
  rescue => e
    update!(
      applied_at: Time.current,
      success: false,
      error_message: e.message
    )
    raise e
  end

  private

  def generate_removal_template(ingredient)
    # Example: Remove gems, routes, etc.
    <<~RUBY
      # Remove gem if it exists
      gsub_file "Gemfile", /^\\s*gem ['"]#{ingredient.name}['"].*$\\n/, ''

      # Remove routes if they exist
      gsub_file "config/routes.rb", /^\\s*# #{ingredient.name} routes.*?end/m, ''

      # Run uninstall generator if it exists
      if File.exist?("bin/rails generate #{ingredient.name}:uninstall")
        rails_command "generate #{ingredient.name}:uninstall"
      end
    RUBY
  end

  def generate_reorder_template(order)
    # Example: Regenerate routes or initializers in the correct order
    recipe.ingredients.includes(:recipe_ingredients).
      order("recipe_ingredients.position").
      map(&:template_content).
      join("\n\n")
  end

  def generate_config_update_template(new_config)
    # Example: Update configuration files
    <<~RUBY
      # Update configuration
      inject_into_file "config/application.rb", after: "class Application < Rails::Application\n" do
        <<~CONFIG
          #{new_config.map { |k, v| "    config.#{k} = #{v.inspect}" }.join("\n")}
        CONFIG
      end
    RUBY
  end
end
