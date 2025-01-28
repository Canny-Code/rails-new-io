class AppGenerationJob < ApplicationJob
  include AcidicJob::Workflow

  def perform(generated_app_id)
    @generated_app = GeneratedApp.find(generated_app_id)
    @logger = AppGeneration::Logger.new(@generated_app)
    @repository_service = AppRepositoryService.new(@generated_app)

    execute_workflow(unique_by: generated_app_id) do |workflow|
      workflow.step :create_github_repository
      workflow.step :generate_rails_app
      workflow.step :push_to_github
      workflow.step :start_ci
      workflow.step :complete_generation
    end
  rescue StandardError => e
    @generated_app.mark_as_failed!(e.message) unless @generated_app.app_status.failed?

    @logger.error("Failed to execute workflow", {
      error: e.message,
      backtrace: e.backtrace.first(10)
    })
    raise
  end

  private

  def create_github_repository
    @repository_service.create_github_repository
    @logger.info("GitHub repo #{@generated_app.name} created successfully")
  end

  def generate_rails_app
    @logger.info("Starting Rails app generation")
    AppGeneration::Orchestrator.new(@generated_app).generate_rails_app
  end

  def push_to_github
    @generated_app.push_to_github!
    @repository_service.push_app_files
    @logger.info("GitHub push finished successfully")
  end

  def start_ci
    @generated_app.start_ci!
  end

  def complete_generation
    @generated_app.mark_as_completed!
  end
end
