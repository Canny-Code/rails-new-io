module AppGeneration
  class Orchestrator
    def initialize(generated_app)
      @logger = AppGeneration::Logger.new(generated_app.app_status)
      @logger.info("Starting app generation workflow")
      @generated_app = generated_app
      @generated_app.logger = @logger
      @repository_service = AppRepositoryService.new(generated_app, @logger)
      @generated_app.repository_service = @repository_service
      @command_execution_service = CommandExecutionService.new(generated_app, @logger)
    end

    def create_github_repository
      @logger.info("Starting GitHub repo creation")
      @generated_app.start_github_repo_creation!
      @repository_service.create_github_repository
      @logger.info("GitHub repo #{@generated_app.name} created successfully")
    end

    def generate_rails_app
      @generated_app.start_rails_app_generation!
      @command_execution_service.execute
      @logger.info("Rails app generation process finished successfully", {
        command: @generated_app.command,
        app_name: @generated_app.name
      })
      if Rails.env.production?
        CommandExecutionService.new(
          @generated_app,
          @logger,
          "bundle lock --add-platform x86_64-linux"
        ).execute
      end
    end

    def install_dependencies
      @logger.info("Installing app dependencies")
      CommandExecutionService.new(
        @generated_app,
        @logger,
        "bundle install"
      ).execute

      # Add Linux platform for CI after everything is installed
      gemfile_lock = File.join(@generated_app.workspace_path, @generated_app.name, "Gemfile.lock")
      unless gemfile_lock.include?("x86_64-linux")
        CommandExecutionService.new(
          @generated_app,
          @logger,
          "bundle lock --add-platform x86_64-linux"
          ).execute

        @repository_service.commit_changes_after_gemfile_lock_update("Updating Gemfile.lock with CI platform")
      end

      @logger.info("Dependencies installed successfully")
    end

    def create_initial_commit
      @logger.info("Creating initial commit")
      @repository_service.create_initial_commit
      @logger.info("Initial commit created successfully")
    end

    def apply_ingredients
      @generated_app.start_ingredient_application!
      @logger.info("Applying ingredients", { count: @generated_app.ingredients.count })
      @generated_app.apply_ingredients
      @logger.info("All ingredients applied successfully")
    end

    def push_to_remote
      @generated_app.start_github_push!
      @logger.info("Starting GitHub push")
      @repository_service.push_to_remote
      @logger.info("GitHub push completed successfully")
    end

    def start_ci
      @generated_app.start_ci!
      @logger.info("Starting CI run")
    end

    def complete_generation
      @generated_app.complete!
      @logger.info("App generation completed successfully")
    end

    def handle_error(error)
      @logger.error("App generation failed", {
        error: error.message,
        backtrace: error.backtrace.join("<br>")
      })

      @generated_app.fail!(error.message) unless @generated_app.failed?
    end
  end
end
