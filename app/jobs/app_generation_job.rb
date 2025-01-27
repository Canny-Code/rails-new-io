class AppGenerationJob < ApplicationJob
  include AcidicJob::Workflow

  def perform(generated_app_id)
    puts "DEBUG: [Job] Starting job with app ID: #{generated_app_id}"
    @generated_app = GeneratedApp.find(generated_app_id)
    puts "DEBUG: [Job] Found app: #{@generated_app.name} (status: #{@generated_app.app_status.status})"
    @logger = AppGeneration::Logger.new(@generated_app)

    execute_workflow(unique_by: generated_app_id) do |workflow|
      puts "DEBUG: [Job] Setting up workflow steps"
      workflow.step :create_github_repository
      workflow.step :generate_rails_app
      workflow.step :push_to_github
      workflow.step :start_ci
      workflow.step :complete_generation
      puts "DEBUG: [Job] Workflow steps set up"
    end
  rescue StandardError => e
    puts "DEBUG: [Job] Error occurred: #{e.message}"
    puts "DEBUG: [Job] Backtrace: #{e.backtrace.first(5).join("\n")}"
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
    puts "DEBUG: [Job] Creating GitHub repository"
    result = AppRepositoryService.new(@generated_app).initialize_repository
    puts "DEBUG: [Job] GitHub repo created: #{result.html_url}"
    @logger.info("GitHub repo #{@generated_app.name} created successfully")
  end

  def generate_rails_app
    puts "DEBUG: [Job] Starting Rails app generation"
    @logger.info("Starting Rails app generation")
    AppGeneration::Orchestrator.new(@generated_app).perform_generation
  end

  def push_to_github
    puts "DEBUG: [Job] Starting GitHub push"
    @generated_app.push_to_github!
    AppRepositoryService.new(@generated_app).push_app_files(source_path: @generated_app.source_path)
    puts "DEBUG: [Job] GitHub push completed"
    @logger.info("GitHub push finished successfully")
  end

  def start_ci
    puts "DEBUG: [Job] Starting CI"
    @generated_app.start_ci!
  end

  def complete_generation
    puts "DEBUG: [Job] Completing generation"
    @generated_app.mark_as_completed!
  end
end
