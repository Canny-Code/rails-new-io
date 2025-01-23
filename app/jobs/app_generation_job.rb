class AppGenerationJob < ApplicationJob
  include AcidicJob::Workflow

  def perform(generated_app_id)
    puts "DEBUG: AppGenerationJob starting for app #{generated_app_id}"
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
    puts "DEBUG: AppGenerationJob caught error: #{e.class} - #{e.message}"
    puts "DEBUG: Current app status: #{@generated_app.app_status.status}"

    # Only mark as failed if not already failed
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
    puts "DEBUG: create_github_repository step starting"
    result = GithubRepositoryService.new(@generated_app)
      .create_repository(repo_name: @generated_app.name)
    puts "DEBUG: create_github_repository step completed"
    result
  end

  def generate_rails_app
    puts "DEBUG: generate_rails_app step starting"
    @logger.info("Starting Rails app generation")
    result = AppGeneration::Orchestrator.new(@generated_app).perform_generation
    puts "DEBUG: generate_rails_app step completed"
    result
  end

  def sync_to_github
    puts "DEBUG: sync_to_github step starting"
    @generated_app.push_to_github!
    @generated_app.initial_git_commit
    @generated_app.sync_to_git
    puts "DEBUG: sync_to_github step completed"
  end

  def start_ci
    puts "DEBUG: start_ci step starting"
    @generated_app.start_ci!
    puts "DEBUG: start_ci step completed"
  end

  def complete_generation
    puts "DEBUG: complete_generation step starting"
    @generated_app.mark_as_completed!
    puts "DEBUG: complete_generation step completed"
  end
end
