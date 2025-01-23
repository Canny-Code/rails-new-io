class GeneratedAppsController < ApplicationController
  before_action :authenticate_user!
  def show
    @generated_app = GeneratedApp.find(params[:id])
  end

  def new
    user_recipes = Recipe.where(created_by: current_user, status: "published")
    template_recipes = Recipe.where(
      created_by: User.find_by(github_username: "trinitytakei"),
      name: [ "omakase", "api only" ],
      status: "published"
    )
    @recipes = (user_recipes + template_recipes).sort_by(&:created_at).reverse
  end

  def create
    recipe = Recipe.where(created_by: current_user).find(params[:generated_app][:recipe_id])

    @generated_app = current_user.generated_apps.create!(
      name: params[:app_name],
      recipe: recipe
    )

    AppGeneration::Orchestrator.new(@generated_app).call

    redirect_to generated_app_log_entries_path(@generated_app)
  end
end
