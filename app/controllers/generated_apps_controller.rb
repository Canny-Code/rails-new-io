class GeneratedAppsController < ApplicationController
  before_action :authenticate_user!
  def show
    @generated_app = GeneratedApp.find(params[:id])
  end

  def new
    @recipes = Recipe.where(created_by: current_user, status: "published").order(created_at: :desc)
  end

  def create
    recipe = Recipe.where(created_by: current_user).find(params[:generated_app][:recipe_id])

    @generated_app = current_user.generated_apps.create!(
      name: params[:app_name],
      recipe: recipe,
      ruby_version: recipe.ruby_version,
      rails_version: recipe.rails_version
    )

    AppGeneration::Orchestrator.new(@generated_app).call

    redirect_to generated_app_log_entries_path(@generated_app)
  end
end
