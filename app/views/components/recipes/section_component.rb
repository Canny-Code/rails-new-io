# app/views/components/recipes/section_component.rb
class Recipes::SectionComponent < Phlex::HTML
  include Phlex::Rails::Helpers::RadioButtonTag
  include Phlex::Rails::Helpers::LabelTag

  def initialize(title:, subtitle:, recipes:, selected_recipe_id:, data: {})
    @title = title
    @subtitle = subtitle
    @recipes = recipes
    @selected_recipe_id = selected_recipe_id
    @data = data
  end

  def view_template
    div(class: "border rounded-lg shadow-sm p-6 mb-6") do
      h3(class: "text-base font-bold text-gray-900") { @title }
      p(class: "text-sm text-gray-600 mb-4") { @subtitle }

      @recipes.each do |recipe|
        div(class: "border-b last:border-0 py-2") do
          div(class: "flex items-start") do
            div(class: "flex items-center h-5", data: { controller: "recipe-selector" }) do
              radio_button_tag "generated_app[recipe_id]",
                recipe.id,
                recipe.id == @selected_recipe_id,
                class: "focus:ring-indigo-500 h-4 w-4 text-indigo-600 border-gray-300",
                data: @data.merge({
                  cli_flags: recipe.cli_flags,
                  ingredients: recipe.recipe_ingredients.joins(:ingredient).pluck(:name).join(",")
                })
            end
            div(class: "ml-3 text-sm") do
              label_tag(nil, class: "font-semibold text-gray-800") { recipe.name }
              p(class: "text-gray-500 mt-1") { recipe.description }
            end
          end
        end
      end
    end
  end
end
