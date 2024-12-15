class GeneratedAppsController < ApplicationController
  before_action :authenticate_user!
  def show
    @generated_app = GeneratedApp.find(params[:id])
  end

  def create
    cli_flags = [
      params[:api_flag],
      params[:database_choice],
      params[:rails_flags]
    ].compact.join(" ")

    recipe = Recipe.find_or_create_by_cli_flags!(cli_flags, current_user)

    @generated_app = current_user.generated_apps.create!(
      name: params[:app_name],
      recipe: recipe,
      ruby_version: recipe.ruby_version,
      rails_version: recipe.rails_version,
      selected_gems: [], # We'll handle this later with ingredients
      configuration_options: {} # We'll handle this later with ingredients
    )

    AppGeneration::Orchestrator.new(@generated_app).call

    redirect_to generated_app_log_entries_path(@generated_app)
  end
end
