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
    @onboarding_step = params[:onboarding_step]
  end

  def edit
    @onboarding_step = params[:onboarding_step]
  end

  def create
    @ingredient = current_user.ingredients.build(ingredient_params)

    if @ingredient.save
      IngredientUiCreator.call(@ingredient)

      WriteIngredientJob.perform_later(ingredient_id: @ingredient.id, user_id: current_user.id)

      redirect_path = if params[:onboarding_step].present?
        next_step = params[:onboarding_step].to_i + 1
        ingredient_path(@ingredient, onboarding_step: next_step)
      else
        ingredient_path(@ingredient)
      end

      redirect_to redirect_path, notice: "Ingredient was successfully created."
    else
      @ingredient.snippets = params.dig(:ingredient, :new_snippets) || []
      @onboarding_step = params[:onboarding_step]
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @ingredient.update(ingredient_params)
      WriteIngredientJob.perform_later(ingredient_id: @ingredient.id, user_id: current_user.id)

      redirect_path = if params[:onboarding_step].present?
        next_step = params[:onboarding_step].to_i + 1
        ingredient_path(@ingredient, onboarding_step: next_step)
      else
        ingredient_path(@ingredient)
      end

      redirect_to redirect_path, notice: "Ingredient was successfully updated."
    else
      @onboarding_step = params[:onboarding_step]
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    data_repository = DataRepositoryService.new(user: current_user)

    DeleteIngredientJob.perform_later(
      user_id: current_user.id,
      ingredient_name: @ingredient.name,
      github_template_path: data_repository.github_template_path(@ingredient),
      local_template_path: data_repository.template_path(@ingredient)
    )

    @ingredient.destroy

    redirect_to ingredients_url, notice: "Ingredient was successfully deleted."
  end

  private

  def set_ingredient
    @ingredient = current_user.ingredients.find(params[:id])
  end

  def ingredient_params
    params.require(:ingredient).permit(
      :name,
      :page_id,
      :description,
      :template_content,
      :category,
      :conflicts_with,
      :requires,
      :configures_with,
      :before_screenshot,
      :after_screenshot,
      new_snippets: []
    )
  end
end
