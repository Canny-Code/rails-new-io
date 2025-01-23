class RecipesController < ApplicationController
  rescue_from ActiveRecord::RecordNotFound, with: :not_found
  before_action :authenticate_user!
  before_action :set_recipe, only: [ :show, :destroy ]

  def index
    @recipes = current_user.recipes.where(status: "published").order(created_at: :desc)
  end

  def show
  end

  def create
    unless recipe_params[:name].present?
      redirect_to setup_recipes_path(slug: "basic-setup"), alert: "A recipe with these settings already exists", status: :unprocessable_entity
      return
    end

    cli_flags = [
      recipe_params[:api_flag],
      recipe_params[:database_choice],
      recipe_params[:rails_flags]
    ].compact.join(" ")

    if existing_recipe = Recipe.find_duplicate(cli_flags)
      redirect_to existing_recipe, alert: "A recipe with these settings already exists"
      return
    end

    @recipe = current_user.recipes.build(
      name: recipe_params[:name],
      description: recipe_params[:description],
      cli_flags: cli_flags,
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

      redirect_to @recipe, notice: "Recipe was successfully created."
    else
      redirect_to setup_recipes_path(slug: "basic-setup"), status: :unprocessable_entity
    end
  end

  def destroy
    @recipe.destroy
    redirect_to recipes_url, notice: "Recipe was successfully deleted."
  end

  private

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
      :rails_flags,
      :name,
      :description,
      :status,
      ingredient_ids: []
    )
  end
end
