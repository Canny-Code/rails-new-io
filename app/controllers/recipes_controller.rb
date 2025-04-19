class RecipesController < ApplicationController
  rescue_from ActiveRecord::RecordNotFound, with: :not_found
  before_action :authenticate_user!
  before_action :set_recipe, only: [ :show, :destroy, :update ]

  def index
    @recipes = current_user.recipes.where(status: "published").order(created_at: :desc)
  end

  def show
  end

  def create
    unless recipe_params[:name].present?
      redirect_to setup_recipes_path(slug: "basic-setup"), alert: "You must specify a name for your recipe", status: :see_other
      return
    end

    ingredient_ids = recipe_params[:ingredient_ids]&.compact_blank.presence || []

    if existing_recipe = Recipe.find_duplicate(current_user.id, cli_flags, ingredient_ids)
      redirect_to existing_recipe, alert: "A recipe with these settings already exists", status: :see_other
      return
    end

    @recipe = current_user.recipes.build(
      name: recipe_params[:name],
      description: recipe_params[:description],
      cli_flags: cli_flags,
      ui_state: JSON.parse(recipe_params[:ui_state]),
      status: recipe_params[:status] || "published",
      ruby_version: RailsNewConfig.ruby_version_for_new_apps,
      rails_version: RailsNewConfig.rails_version_for_new_apps
    )

    if @recipe.save
      if recipe_params[:ingredient_ids].present?
        recipe_params[:ingredient_ids].each do |ingredient_id|
          ingredient = Ingredient.find_by(id: ingredient_id)
          @recipe.add_ingredient!(ingredient) if ingredient
        end
      end

      WriteRecipeJob.perform_later(recipe_id: @recipe.id, user_id: current_user.id)

      redirect_path = if params[:onboarding_step].present?
        recipe_path(@recipe, onboarding_step: params[:onboarding_step].to_i + 1)
      else
        recipe_path(@recipe)
      end

      redirect_to redirect_path, notice: "Recipe was successfully created."
    else
      error_messages = @recipe.errors.full_messages.join(", ")
      redirect_to setup_recipes_path(slug: "basic-setup"), alert: "Failed to save recipe: #{error_messages}", status: :see_other
    end
  end

  def update
    @recipe.update(
      name: recipe_params[:name],
      description: recipe_params[:description],
      cli_flags:,
      ui_state: JSON.parse(recipe_params[:ui_state]),
      status: recipe_params[:status],
      ruby_version: RailsNewConfig.ruby_version_for_new_apps,
      rails_version: RailsNewConfig.rails_version_for_new_apps
    )

    @recipe.recipe_ingredients.destroy_all

    if recipe_params[:ingredient_ids].present?
      recipe_params[:ingredient_ids].each do |ingredient_id|
        ingredient = Ingredient.find_by(id: ingredient_id)
        @recipe.add_ingredient!(ingredient) if ingredient
      end
    end

    WriteRecipeJob.perform_later(recipe_id: @recipe.id, user_id: current_user.id)

    redirect_to @recipe, notice: "Recipe was successfully updated."
  end

  def destroy
    DeleteRecipeJob.perform_later(user_id: current_user.id, recipe_name: @recipe.name)

    @recipe.destroy
    redirect_to recipes_url, notice: "Recipe was successfully deleted."
  end

  private

  def cli_flags
    @_cli_flags ||= [
      recipe_params[:api_flag],
      recipe_params[:database_choice],
      recipe_params[:javascript_choice],
      recipe_params[:css_choice],
      recipe_params[:rails_flags]
    ].compact.join(" ")
  end

  def not_found
    head :not_found
  end

  def set_recipe
    @recipe = current_user.recipes.find(params[:id])
  end

  def recipe_params
    params.require(:recipe).permit(
      :id,
      :api_flag,
      :database_choice,
      :javascript_choice,
      :css_choice,
      :rails_flags,
      :name,
      :description,
      :status,
      :ui_state,
      ingredient_ids: [],
    )
  end
end
