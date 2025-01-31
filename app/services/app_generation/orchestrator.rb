module AppGeneration
  class Orchestrator
    def initialize(generated_app)
      @generated_app = generated_app
      @logger = AppGeneration::Logger.new(generated_app.app_status)
      @generated_app.logger = @logger
      @repository_service = AppRepositoryService.new(generated_app, @logger)
      @command_execution_service = CommandExecutionService.new(generated_app, @logger)
      @logger.info("Starting app generation workflow")
    end

    def create_github_repository
      @logger.info("Starting GitHub repo creation")
      @repository_service.create_github_repository
      @logger.info("GitHub repo #{@generated_app.name} created successfully")
    end

    def generate_rails_app
      @generated_app.start_rails_app_generation!
      @logger.info("Executing Rails new command")
      @command_execution_service.execute
      @logger.info("Rails app generation process finished successfully", {
        command: @generated_app.command,
        app_name: @generated_app.name
      })
    end

    def create_initial_commit
      @logger.info("Creating initial commit")
      @repository_service.create_initial_commit
      @logger.info("Initial commit created successfully")
    end

    def apply_ingredients
      @logger.info("Applying ingredients", { count: @generated_app.ingredients.count })
      @generated_app.apply_ingredients
      @logger.info("All ingredients applied successfully")
    end

    def push_to_remote
      @logger.info("Starting GitHub push")
      @generated_app.start_github_push!
      @repository_service.push_to_remote
      @logger.info("GitHub push completed successfully")
    end

    def start_ci
      @logger.info("Starting CI")
      @generated_app.start_ci!
      @logger.info("CI started successfully")
    end

    def complete_generation
      @logger.info("Completing app generation")
      @generated_app.complete!
      @logger.info("App generation completed successfully")
    end

    def handle_error(error)
      @logger.error("App generation failed", {
        error: error.message,
        backtrace: error.backtrace.join("\n")
      })

      @generated_app.fail!(error.message) unless @generated_app.failed?
    end
  end
end
