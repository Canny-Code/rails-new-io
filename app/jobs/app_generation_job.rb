class AppGenerationJob < ApplicationJob
  include AcidicJob::Workflow

  def perform(generated_app_id)
    @generated_app = GeneratedApp.find(generated_app_id)
    @logger = AppGeneration::Logger.new(@generated_app)

    puts "DEBUG: Job starting with state: #{@generated_app.status}"
    execute_workflow(unique_by: generated_app_id) do |workflow|
      workflow.step :create_github_repository
      workflow.step :generate_rails_app
      workflow.step :sync_to_github
      workflow.step :start_ci
      workflow.step :complete_generation
    end
  rescue StandardError => e
    puts "DEBUG: Job failed with error: #{e.message}"
    puts "DEBUG: State before failure: #{@generated_app.status}"
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
    puts "DEBUG: create_github_repository starting with state: #{@generated_app.status}"
    result = AppRepositoryService.new(@generated_app).initialize_repository
    puts "DEBUG: create_github_repository finished with state: #{@generated_app.status}"
    result
  end

  def generate_rails_app
    puts "DEBUG: generate_rails_app starting with state: #{@generated_app.status}"
    @logger.info("Starting Rails app generation")
    result = AppGeneration::Orchestrator.new(@generated_app).perform_generation
    puts "DEBUG: generate_rails_app finished with state: #{@generated_app.status}"
    result
  end

  def sync_to_github
    puts "DEBUG: sync_to_github starting with state: #{@generated_app.status}"
    @generated_app.push_to_github!
    @generated_app.initial_git_commit
    @generated_app.sync_to_git
    puts "DEBUG: sync_to_github finished with state: #{@generated_app.status}"
  end

  def start_ci
    puts "DEBUG: start_ci starting with state: #{@generated_app.status}"
    @generated_app.start_ci!
    puts "DEBUG: start_ci finished with state: #{@generated_app.status}"
  end

  def complete_generation
    puts "DEBUG: complete_generation starting with state: #{@generated_app.status}"
    @generated_app.mark_as_completed!
    puts "DEBUG: complete_generation finished with state: #{@generated_app.status}"
  end
end
