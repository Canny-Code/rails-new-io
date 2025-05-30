class IngredientsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_ingredient, only: [ :show, :edit, :update, :destroy ]
  before_action :authorize_action, only: [ :edit, :update, :destroy ]

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
  end

  def create
    @ingredient = current_user.ingredients.build(ingredient_params)

    if @ingredient.save
      begin
        IngredientUiCreator.call(@ingredient, page_title: @ingredient.page.title)
      rescue IngredientUiCreationError => e
        Rails.logger.error("Failed to create ingredient UI: #{e.message}")
        Rails.logger.error(e.backtrace.join("\n"))
        @ingredient.destroy
        @ingredient.new_snippets = params.dig(:ingredient, :new_snippets) || []
        @onboarding_step = params[:onboarding_step]
        flash[:alert] = "There was a problem creating the ingredient. Please try again or contact support if the problem persists."
        render :new, status: :unprocessable_entity
        return
      end

      WriteIngredientJob.perform_later(ingredient_id: @ingredient.id, user_id: current_user.id)

      redirect_path = if params[:onboarding_step].present? && !current_user.onboarding_completed
        next_step = params[:onboarding_step].to_i + 1
        ingredient_path(@ingredient, onboarding_step: next_step)
      else
        ingredient_path(@ingredient)
      end

      redirect_to redirect_path, notice: "Ingredient was successfully created."
    else
      @ingredient.new_snippets = params.dig(:ingredient, :new_snippets) || []
      @onboarding_step = params[:onboarding_step]
      flash[:alert] = "Error creating ingredient: #{@ingredient.errors.full_messages.join(", ")}"
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @ingredient.update(ingredient_params)
      WriteIngredientJob.perform_later(ingredient_id: @ingredient.id, user_id: current_user.id)

      redirect_to ingredient_path(@ingredient), notice: "Ingredient was successfully updated."
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

    IngredientUiDestroyer.call(@ingredient)

    redirect_to ingredients_url, notice: "Ingredient was successfully deleted."
  end

  private

  def set_ingredient
    @ingredient = Ingredient.find(params[:id])
  end

  def authorize_action
    unless @ingredient.created_by == Current.user || current_user.github_username == "rails-new-io"
      redirect_to ingredient_path(@ingredient), notice: "You can only perform this action on your own ingredients!"
    end
  end

  def ingredient_params
    params.require(:ingredient).permit(
      :name,
      :page_id,
      :description,
      :template_content,
      :category,
      :sub_category,
      :conflicts_with,
      :requires,
      :configures_with,
      :before_screenshot,
      :after_screenshot,
      new_snippets: []
    )
  end
end
