class GeneratedAppsController < ApplicationController
  before_action :authenticate_user!
  def show
    @generated_app = GeneratedApp.find(params[:id])
  end

  def new
    @pre_cooked_recipes = Recipe.where(
      created_by: User.find_by(github_username: "trinitytakei"),
      name: [ "Omakase", "API Only" ],
      status: "published"
    )

    @recipes = Recipe.where(created_by: current_user, status: "published") - @pre_cooked_recipes
  end

  def create
    recipe = Recipe.where(created_by: current_user).find(params[:generated_app][:recipe_id])

    @generated_app = current_user.generated_apps.create!(
      name: params[:app_name],
      recipe: recipe
    )

    AppGeneration::Orchestrator.new(@generated_app).enqueue_app_generation_job

    redirect_to generated_app_log_entries_path(@generated_app)
  end
end
