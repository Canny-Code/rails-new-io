module AppGeneration
  class Orchestrator
    def initialize(generated_app)
      @generated_app = generated_app
      @logger = AppGeneration::Logger.new(generated_app)
    end

    def call
      validate_initial_state!

      AppGenerationJob.perform_later(@generated_app.id)

      true
    rescue AppGeneration::Errors::InvalidStateError
      raise
    rescue StandardError => e
      @logger.error("Failed to start app generation", { error: e.message })
      @generated_app.mark_as_failed!(e.message)
      false
    end

    def perform_generation
      @logger.info("Starting app generation")

      # Mark as generating and create the Rails app
      @generated_app.generate!
      execute_rails_new_command

      # Then apply each ingredient
      apply_ingredients

      @logger.info("App generation completed successfully")
    rescue StandardError => e
      @logger.error("App generation failed", { error: e.message })
      @generated_app.mark_as_failed!(e.message)
      raise
    end

    private

    def execute_rails_new_command
      @logger.info("Executing Rails new command")
      CommandExecutionService.new(@generated_app, @generated_app.command).execute
    end

    def apply_ingredients
      @logger.info("Applying ingredients")
      @generated_app.ingredients.each do |ingredient|
        # Verify template exists before trying to apply it
        template_path = DataRepositoryService.new(user: @generated_app.user).template_path(ingredient)

        unless File.exist?(template_path)
          @logger.error("Template file not found", { path: template_path })
          raise "Template file not found: #{template_path}"
        end

        @generated_app.apply_ingredient!(ingredient)
        @logger.info("Finished applying ingredient", { ingredient: ingredient.name })
      end
    end

    def validate_initial_state!
      return if @generated_app.pending?

      raise AppGeneration::Errors::InvalidStateError, "App must be in pending state to start generation"
    end
  end
end
