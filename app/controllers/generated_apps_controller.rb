class GeneratedAppsController < ApplicationController
  before_action :authenticate_user!
  def show
    @generated_app = GeneratedApp.find(params[:id])
  end

  def new
    @pre_cooked_recipes = Recipe.includes(recipe_ingredients: :ingredient).where(
      created_by: User.find_by(github_username: "trinitytakei"),
      name: [ "Omakase", "API Only" ],
      status: "published"
    )

    @recipes = Recipe.includes(recipe_ingredients: :ingredient).where(created_by: current_user, status: "published") - @pre_cooked_recipes
  end

  def create
    begin
      recipe = Recipe.where(created_by: User.where(admin: true).or(User.where(id: current_user.id))).find(params[:generated_app][:recipe_id])

      @generated_app = current_user.generated_apps.new(
        name: params[:app_name],
        generated_with_recipe_version: recipe.head_commit_sha,
        recipe: recipe,
      )

      if @generated_app.save
        AppGenerationJob.perform_later(@generated_app.id)
        redirect_path = if params[:onboarding_step].present?
          generated_app_log_entries_path(@generated_app, onboarding_step: params[:onboarding_step])
        else
          generated_app_log_entries_path(@generated_app)
        end
        redirect_to redirect_path
      else
        redirect_to new_generated_app_path, alert: "Failed to create generated app: #{@generated_app.errors.full_messages.to_sentence}"
      end
    rescue ActiveRecord::RecordNotFound
      redirect_to new_generated_app_path, alert: "Recipe not found - you either don't have access to this recipe or it doesn't exist"
    end
  end
end
