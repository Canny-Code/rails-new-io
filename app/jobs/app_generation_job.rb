class AppGenerationJob < ApplicationJob
  include AcidicJob::Workflow

  def perform(generated_app_id)
    @generated_app = GeneratedApp.find(generated_app_id)
    @logger = AppGeneration::Logger.new(@generated_app)

    execute_workflow(unique_by: generated_app_id) do |workflow|
      workflow.step :create_github_repository
      workflow.step :generate_rails_app
      workflow.step :push_to_github
      workflow.step :start_ci
      workflow.step :complete_generation
    end
  rescue StandardError => e
    @generated_app.mark_as_failed!(e.message)
    @logger.error("Failed to execute workflow", {
      error: e.message,
      backtrace: e.backtrace.first(5)
    })
    raise
  end

  private

  def create_github_repository
    GithubRepositoryService.new(@generated_app)
      .create_repository(@generated_app.name)
  end

  def generate_rails_app
    @generated_app.generate!
    command = "rails new #{@generated_app.name} #{@generated_app.recipe.cli_flags}"
    CommandExecutionService.new(@generated_app, command).execute
  end

  def push_to_github
    GithubCodePushService.new(@generated_app).execute
  end

  def start_ci
    # Right now, we don't actually start a CI run.
    # It's triggered by pushing to GitHub.
    # In the future (if there will be a CI service)
    # we'll start a CI run here.
    @generated_app.start_ci!
  end

  def complete_generation
    @generated_app.mark_as_completed!
  end
end
