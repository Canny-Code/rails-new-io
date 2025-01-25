class AppGenerationJob < ApplicationJob
  include AcidicJob::Workflow

  def perform(generated_app_id)
    @generated_app = GeneratedApp.find(generated_app_id)
    @logger = AppGeneration::Logger.new(@generated_app)

    execute_workflow(unique_by: generated_app_id) do |workflow|
      workflow.step :create_github_repository
      workflow.step :generate_rails_app
      workflow.step :sync_to_github
      workflow.step :start_ci
      workflow.step :complete_generation
    end
  rescue StandardError => e
    unless @generated_app.app_status.failed?
      @generated_app.mark_as_failed!(e.message)
    end

    @logger.error("Failed to execute workflow", {
      error: e.message,
      backtrace: e.backtrace.first(5)
    })
    raise
  end

  private

  def create_github_repository
    AppRepositoryService.new(@generated_app).initialize_repository
    @logger.info("GitHub repo #{@generated_app.name} created successfully")
  end

  def generate_rails_app
    @logger.info("Starting Rails app generation")
    result = AppGeneration::Orchestrator.new(@generated_app).perform_generation
    result
  end

  def sync_to_github
    @generated_app.push_to_github!
    @generated_app.initial_git_commit
    @generated_app.sync_to_git
    @logger.info("GitHub push finished successfully")
  end

  def start_ci
    @generated_app.start_ci!
  end

  def complete_generation
    @generated_app.mark_as_completed!
  end
end
