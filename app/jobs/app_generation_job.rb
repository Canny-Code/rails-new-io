class AppGenerationJob < ApplicationJob
  include AcidicJob::Workflow

  def perform(generated_app_id)
    @generated_app = GeneratedApp.find(generated_app_id)
    @logger = AppGeneration::Logger.new(@generated_app)

    execute_workflow(unique_by: generated_app_id) do |workflow|
      workflow.step :create_github_repository
      workflow.step :generate_rails_app
      workflow.step :push_to_github
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
    command = build_rails_command
    CommandExecutionService.new(@generated_app, command).execute
  end

  def push_to_github
    GithubCodePushService.new(@generated_app).execute
  end

  def complete_generation
    @generated_app.mark_as_completed!
  end

  def build_rails_command
    "rails new #{@generated_app.name} --skip-action-mailbox --skip-jbuilder --asset-pipeline=propshaft --javascript=esbuild --css=tailwind --skip-spring"
  end
end
