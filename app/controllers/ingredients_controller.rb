class IngredientsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_ingredient, only: [ :show, :edit, :update, :destroy ]

  def index
    @ingredients = current_user.ingredients
  end

  def show
  end

  def new
    @ingredient = current_user.ingredients.build
  end

  def edit
  end

  def create
    @ingredient = current_user.ingredients.build(ingredient_params)

    if @ingredient.save
      IngredientUiCreator.call(@ingredient)

      WriteIngredientJob.perform_later(ingredient_id: @ingredient.id, user_id: current_user.id)

      redirect_to @ingredient, notice: "Ingredient was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @ingredient.update(ingredient_params)
      WriteIngredientJob.perform_later(ingredient_id: @ingredient.id, user_id: current_user.id)

      redirect_to @ingredient, notice: "Ingredient was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    DeleteIngredientJob.perform_later(ingredient_id: @ingredient.id, user_id: current_user.id)

    redirect_to ingredients_url, notice: "Ingredient was successfully deleted."
  end

  private

  def set_ingredient
    @ingredient = current_user.ingredients.find(params[:id])
  end

  def ingredient_params
    params.require(:ingredient).permit(
      :name,
      :description,
      :template_content,
      :category,
      :conflicts_with,
      :requires,
      :configures_with
    )
  end
end
