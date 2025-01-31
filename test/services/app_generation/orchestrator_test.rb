require "test_helper"
require_relative "../../../app/services/app_generation/errors"

module AppGeneration
  class OrchestratorTest < ActiveSupport::TestCase
    setup do
      @generated_app = generated_apps(:pending_app)
      @original_adapter = ActiveJob::Base.queue_adapter
      ActiveJob::Base.queue_adapter = :solid_queue
    end

    teardown do
      ActiveJob::Base.queue_adapter = @original_adapter
    end

    test "validates app must be in pending state" do
      @generated_app.app_status.update!(status: "generating_rails_app")
      @generated_app.reload

      assert_equal "generating_rails_app", @generated_app.status
      assert_not @generated_app.pending?

      orchestrator = Orchestrator.new(@generated_app)

      error = assert_raises(AASM::InvalidTransition) do
        orchestrator.create_github_repository
      end

      assert_equal "Event 'start_github_repo_creation' cannot transition from 'generating_rails_app'.", error.message
    end

    test "successfully performs app generation" do
      # Set up logger
      @logger = AppGeneration::Logger.new(@generated_app.app_status)
      AppGeneration::Logger.expects(:new).with(@generated_app.app_status).returns(@logger).once

      # Mock command execution
      command_service = mock("command_service")
      command_service.expects(:execute).once.returns(true)
      CommandExecutionService.expects(:new).with(@generated_app, @logger).returns(command_service)

      # Mock repository service
      repository_service = mock("repository_service")
      repository_service.expects(:create_github_repository).once.returns(true).tap do
        @generated_app.app_status.start_github_repo_creation!
      end
      AppRepositoryService.expects(:new).with(@generated_app, @logger).returns(repository_service)

      # Mock ingredient application
      ingredient = ingredients(:rails_authentication)
      @generated_app.stubs(:ingredients).returns([ ingredient ])
      @generated_app.expects(:apply_ingredients).once.tap { puts "DEBUG: apply_ingredients expectation set" }

      # Mock template path verification
      data_repository = mock("data_repository")
      data_repository.stubs(:template_path).returns("path/to/template.rb")
      DataRepositoryService.stubs(:new).with(user: @generated_app.user).returns(data_repository)

      # Stub all file system interactions
      File.stubs(:exist?).returns(true)

      # Expect proper logging
      sequence = sequence("generation_logging")
      @logger.expects(:info).with("Starting app generation workflow").in_sequence(sequence)
      @logger.expects(:info).with("Starting GitHub repo creation").in_sequence(sequence)
      @logger.expects(:info).with("GitHub repo #{@generated_app.name} created successfully").in_sequence(sequence)
      @logger.expects(:info).with("Executing Rails new command").in_sequence(sequence)
      @logger.expects(:info).with("Rails app generation process finished successfully", {
        command: @generated_app.command,
        app_name: @generated_app.name
      }).in_sequence(sequence)
      @logger.expects(:info).with("Applying ingredients", { count: 1 }).in_sequence(sequence)
      @logger.expects(:info).with("All ingredients applied successfully").in_sequence(sequence)

      # Create orchestrator and perform generation
      puts "DEBUG: Creating orchestrator"
      @orchestrator = Orchestrator.new(@generated_app)
      puts "DEBUG: App status after creating orchestrator: #{@generated_app.status}"

      puts "DEBUG: Creating GitHub repo"
      @orchestrator.create_github_repository
      puts "DEBUG: App status after creating GitHub repo: #{@generated_app.status}"

      puts "DEBUG: Calling generate_rails_app"
      @orchestrator.generate_rails_app
      puts "DEBUG: App status after generate_rails_app: #{@generated_app.status}"

      puts "DEBUG: Calling apply_ingredients"
      @orchestrator.apply_ingredients
      puts "DEBUG: App status after apply_ingredients: #{@generated_app.status}"

      # Verify state changes
      puts "DEBUG: Final app status before assertion: #{@generated_app.status}"
      assert_equal "generating_rails_app", @generated_app.status
    end

    test "handles missing template files during generation" do
      error_message = "Template file not found: /nonexistent/path/template.rb"

      # Set up logger
      @logger = AppGeneration::Logger.new(@generated_app.app_status)
      AppGeneration::Logger.expects(:new).with(@generated_app.app_status).returns(@logger).once

      # Mock command execution
      command_service = mock("command_service")
      command_service.expects(:execute).once.returns(true)
      CommandExecutionService.expects(:new).with(@generated_app, @logger).returns(command_service)

      # Mock repository service
      repository_service = mock("repository_service")
      repository_service.expects(:create_github_repository).once.returns(true).tap do
        puts "DEBUG: Starting GitHub repo creation"
        @generated_app.app_status.start_github_repo_creation!
        puts "DEBUG: App status after start_github_repo_creation!: #{@generated_app.status}"
      end
      AppRepositoryService.stubs(:new).with(@generated_app, @logger).returns(repository_service)

      # Mock ingredient setup
      ingredient = ingredients(:rails_authentication)
      @generated_app.stubs(:ingredients).returns([ ingredient ])
      @generated_app.expects(:apply_ingredients).raises(StandardError.new(error_message))

      # Mock template path verification to fail
      data_repository = mock("data_repository")
      data_repository.stubs(:template_path).returns("/nonexistent/path/template.rb")
      DataRepositoryService.stubs(:new).with(user: @generated_app.user).returns(data_repository)
      File.stubs(:exist?).with("/nonexistent/path/template.rb").returns(false)

      # Expect proper logging
      sequence = sequence("error_logging")
      @logger.expects(:info).with("Starting app generation workflow").in_sequence(sequence)
      @logger.expects(:info).with("Starting GitHub repo creation").in_sequence(sequence)
      @logger.expects(:info).with("GitHub repo #{@generated_app.name} created successfully").in_sequence(sequence)
      @logger.expects(:info).with("Executing Rails new command").in_sequence(sequence)
      @logger.expects(:info).with("Rails app generation process finished successfully", {
        command: @generated_app.command,
        app_name: @generated_app.name
      }).in_sequence(sequence)
      @logger.expects(:info).with("Applying ingredients", { count: 1 }).in_sequence(sequence)
      @logger.expects(:error).with("App generation failed", {
        error: error_message,
        backtrace: kind_of(String)
      }).in_sequence(sequence)

      # Create orchestrator and perform generation
      puts "DEBUG: Creating orchestrator"
      @orchestrator = Orchestrator.new(@generated_app)
      puts "DEBUG: App status after creating orchestrator: #{@generated_app.status}"

      puts "DEBUG: Creating GitHub repo"
      @orchestrator.create_github_repository
      puts "DEBUG: App status after creating GitHub repo: #{@generated_app.status}"

      puts "DEBUG: Calling generate_rails_app"
      @orchestrator.generate_rails_app
      puts "DEBUG: App status after generate_rails_app: #{@generated_app.status}"

      assert_raises(StandardError) do
        puts "DEBUG: Calling apply_ingredients"
        @orchestrator.apply_ingredients
      rescue => e
        puts "DEBUG: Handling error: #{e.message}"
        puts "DEBUG: App status before handle_error: #{@generated_app.status}"
        @orchestrator.handle_error(e)
        puts "DEBUG: App status after handle_error: #{@generated_app.status}"
        raise
      end

      # Verify final state
      puts "DEBUG: Final app status before assertions: #{@generated_app.status}"
      assert_equal "failed", @generated_app.status
      assert_equal error_message, @generated_app.error_message
    end

    test "handles errors during rails new command" do
      error_message = "Rails new command failed"
      error = StandardError.new(error_message)
      begin
        raise error
      rescue => error
        # Now error has a backtrace
      end

      # Set up logger
      @logger = AppGeneration::Logger.new(@generated_app.app_status)
      AppGeneration::Logger.expects(:new).with(@generated_app.app_status).returns(@logger).once

      # Mock repository service
      repository_service = mock("repository_service")
      repository_service.expects(:create_github_repository).once.returns(true).tap do
        puts "DEBUG: Starting GitHub repo creation"
        @generated_app.app_status.start_github_repo_creation!
        puts "DEBUG: App status after start_github_repo_creation!: #{@generated_app.status}"
      end
      AppRepositoryService.expects(:new).with(@generated_app, @logger).returns(repository_service)

      # Mock command execution to fail
      command_service = mock("command_service")
      command_service.expects(:execute).raises(error)
      CommandExecutionService.expects(:new).with(@generated_app, @logger).returns(command_service)

      # Expect proper logging
      sequence = sequence("error_logging")
      @logger.expects(:info).with("Starting app generation workflow").in_sequence(sequence)
      @logger.expects(:info).with("Starting GitHub repo creation").in_sequence(sequence)
      @logger.expects(:info).with("GitHub repo #{@generated_app.name} created successfully").in_sequence(sequence)
      @logger.expects(:info).with("Executing Rails new command").in_sequence(sequence)
      @logger.expects(:error).with("App generation failed", {
        error: error_message,
        backtrace: kind_of(String)
      }).in_sequence(sequence)

      # Create orchestrator and perform generation
      puts "DEBUG: Creating orchestrator"
      @orchestrator = Orchestrator.new(@generated_app)
      puts "DEBUG: App status after creating orchestrator: #{@generated_app.status}"

      puts "DEBUG: Creating GitHub repo"
      @orchestrator.create_github_repository
      puts "DEBUG: App status after creating GitHub repo: #{@generated_app.status}"

      assert_raises(StandardError) do
        puts "DEBUG: Calling generate_rails_app"
        @orchestrator.generate_rails_app
      rescue => e
        puts "DEBUG: Handling error: #{e.message}"
        puts "DEBUG: App status before handle_error: #{@generated_app.status}"
        @orchestrator.handle_error(e)
        puts "DEBUG: App status after handle_error: #{@generated_app.status}"
        raise
      end

      # Verify final state
      puts "DEBUG: Final app status before assertions: #{@generated_app.status}"
      assert_equal "failed", @generated_app.status
      assert_equal error_message, @generated_app.error_message
    end

    test "handles errors during ingredient application" do
      error_message = "Failed to apply ingredient"
      error = StandardError.new(error_message)
      begin
        raise error
      rescue => error
        # Now error has a backtrace
      end

      # Set up logger
      @logger = AppGeneration::Logger.new(@generated_app.app_status)
      AppGeneration::Logger.expects(:new).with(@generated_app.app_status).returns(@logger).once

      # Mock command execution
      command_service = mock("command_service")
      command_service.expects(:execute).once.returns(true).tap { puts "DEBUG: command_service.execute called" }
      CommandExecutionService.expects(:new).with(@generated_app, @logger).returns(command_service)

      # Mock repository service
      repository_service = mock("repository_service")
      repository_service.expects(:create_github_repository).once.returns(true).tap do
        puts "DEBUG: Starting GitHub repo creation"
        @generated_app.app_status.start_github_repo_creation!
        puts "DEBUG: App status after start_github_repo_creation!: #{@generated_app.status}"
      end
      AppRepositoryService.expects(:new).with(@generated_app, @logger).returns(repository_service)

      # Mock ingredient setup
      ingredient = ingredients(:rails_authentication)
      @generated_app.stubs(:ingredients).returns([ ingredient ])

      # Mock template path verification
      data_repository = mock("data_repository")
      data_repository.stubs(:template_path).returns("path/to/template.rb")
      DataRepositoryService.stubs(:new).with(user: @generated_app.user).returns(data_repository)
      File.stubs(:exist?).with("path/to/template.rb").returns(true)

      # Expect proper logging
      sequence = sequence("error_logging")
      @logger.expects(:info).with("Starting app generation workflow").in_sequence(sequence)
      @logger.expects(:info).with("Starting GitHub repo creation").in_sequence(sequence)
      @logger.expects(:info).with("GitHub repo #{@generated_app.name} created successfully").in_sequence(sequence)
      @logger.expects(:info).with("Executing Rails new command").in_sequence(sequence)
      @logger.expects(:info).with("Rails app generation process finished successfully", {
        command: @generated_app.command,
        app_name: @generated_app.name
      }).in_sequence(sequence)
      @logger.expects(:info).with("Applying ingredients", { count: 1 }).in_sequence(sequence)
      @logger.expects(:error).with("App generation failed", {
        error: error_message,
        backtrace: kind_of(String)
      }).in_sequence(sequence)

      # Mock ingredient application to fail
      @generated_app.expects(:apply_ingredients).raises(error).tap { puts "DEBUG: apply_ingredients expectation set to raise error" }

      # Create orchestrator and perform generation
      puts "DEBUG: Creating orchestrator"
      @orchestrator = Orchestrator.new(@generated_app)
      puts "DEBUG: App status after creating orchestrator: #{@generated_app.status}"

      puts "DEBUG: Creating GitHub repo"
      @orchestrator.create_github_repository
      puts "DEBUG: App status after creating GitHub repo: #{@generated_app.status}"

      puts "DEBUG: Calling generate_rails_app"
      @orchestrator.generate_rails_app
      puts "DEBUG: App status after generate_rails_app: #{@generated_app.status}"

      assert_raises(StandardError) do
        puts "DEBUG: Calling apply_ingredients"
        @orchestrator.apply_ingredients
      rescue => e
        puts "DEBUG: Handling error: #{e.message}"
        puts "DEBUG: App status before handle_error: #{@generated_app.status}"
        @orchestrator.handle_error(e)
        puts "DEBUG: App status after handle_error: #{@generated_app.status}"
        raise
      end

      # Verify final state
      puts "DEBUG: Final app status before assertions: #{@generated_app.status}"
      assert_equal "failed", @generated_app.status
      assert_equal error_message, @generated_app.error_message
    end

    test "performs generation with actual ingredients" do
      # Set up logger
      @logger = AppGeneration::Logger.new(@generated_app.app_status)
      AppGeneration::Logger.expects(:new).with(@generated_app.app_status).returns(@logger).once

      # Mock command execution
      command_service = mock("command_service")
      command_service.expects(:execute).once.returns(true).tap do
        puts "DEBUG: command_service.execute called"
      end
      CommandExecutionService.expects(:new).with(@generated_app, @logger).returns(command_service)

      # Mock repository service
      repository_service = mock("repository_service")
      repository_service.expects(:create_github_repository).once.returns(true).tap do
        puts "DEBUG: Starting GitHub repo creation"
        @generated_app.app_status.start_github_repo_creation!
        puts "DEBUG: App status after start_github_repo_creation!: #{@generated_app.status}"
      end
      AppRepositoryService.stubs(:new).with(@generated_app, @logger).returns(repository_service)

      # Mock template path verification
      data_repository = mock("data_repository")
      data_repository.stubs(:template_path).returns("path/to/template.rb")
      data_repository.stubs(:class).returns(DataRepositoryService)
      data_repository.expects(:write_recipe).with(instance_of(Recipe), repo_name: "rails-new-io-data-test").twice
      DataRepositoryService.stubs(:new).with(user: @generated_app.user).returns(data_repository)
      File.stubs(:exist?).with("path/to/template.rb").returns(true)

      # Clean up any existing ingredients
      @generated_app.recipe.recipe_ingredients.destroy_all

      # Add ingredients to the recipe
      ingredient1 = ingredients(:rails_authentication)
      ingredient2 = ingredients(:api_setup)
      @generated_app.recipe.add_ingredient!(ingredient1)
      @generated_app.recipe.add_ingredient!(ingredient2)

      # Verify ingredients are added in correct order
      assert_equal [ ingredient1.id, ingredient2.id ], @generated_app.recipe.ingredients.order(:position).pluck(:id)
      assert_equal 1, @generated_app.recipe.recipe_ingredients.first.position
      assert_equal 2, @generated_app.recipe.recipe_ingredients.last.position

      # Unstub ingredients to use actual implementation
      @generated_app.unstub(:ingredients)

      # Set up logging sequence
      sequence = sequence("generation_logging")
      @logger.expects(:info).with("Starting app generation workflow").in_sequence(sequence)
      @logger.expects(:info).with("Starting GitHub repo creation").in_sequence(sequence)
      @logger.expects(:info).with("GitHub repo #{@generated_app.name} created successfully").in_sequence(sequence)
      @logger.expects(:info).with("Executing Rails new command").in_sequence(sequence)
      @logger.expects(:info).with("Rails app generation process finished successfully", {
        command: @generated_app.command,
        app_name: @generated_app.name
      }).in_sequence(sequence)
      @logger.expects(:info).with("Applying ingredients", { count: 2 }).in_sequence(sequence)
      @logger.expects(:info).with("All ingredients applied successfully").in_sequence(sequence)

      # Mock apply_ingredients to succeed
      @generated_app.expects(:apply_ingredients).once.returns(true)

      # Create orchestrator and perform generation
      puts "DEBUG: Creating orchestrator"
      @orchestrator = Orchestrator.new(@generated_app)
      puts "DEBUG: App status after creating orchestrator: #{@generated_app.status}"

      puts "DEBUG: Creating GitHub repo"
      @orchestrator.create_github_repository
      puts "DEBUG: App status after creating GitHub repo: #{@generated_app.status}"

      puts "DEBUG: Calling generate_rails_app"
      @orchestrator.generate_rails_app
      puts "DEBUG: App status after generate_rails_app: #{@generated_app.status}"

      puts "DEBUG: Calling apply_ingredients"
      @orchestrator.apply_ingredients
      puts "DEBUG: App status after apply_ingredients: #{@generated_app.status}"

      # Verify final state
      puts "DEBUG: Final app status before assertions: #{@generated_app.status}"
      assert_equal "generating_rails_app", @generated_app.status
    end

    test "successfully creates initial commit" do
      # Set up logger
      @logger = AppGeneration::Logger.new(@generated_app.app_status)
      AppGeneration::Logger.expects(:new).with(@generated_app.app_status).returns(@logger).once

      # Set up app status to be ready for commit
      @generated_app.app_status.start_github_repo_creation!
      @generated_app.app_status.start_rails_app_generation!
      puts "DEBUG: App status after setup: #{@generated_app.status}"

      # Mock repository service
      repository_service = mock("repository_service")
      repository_service.expects(:create_initial_commit).once.returns(true)
      AppRepositoryService.expects(:new).with(@generated_app, @logger).returns(repository_service)

      # Mock command execution service to prevent Rails new validation
      command_service = mock("command_service")
      CommandExecutionService.expects(:new).with(@generated_app, @logger).returns(command_service)

      # Expect proper logging
      sequence = sequence("commit_logging")
      @logger.expects(:info).with("Starting app generation workflow").in_sequence(sequence)
      @logger.expects(:info).with("Creating initial commit").in_sequence(sequence)
      @logger.expects(:info).with("Initial commit created successfully").in_sequence(sequence)

      # Create orchestrator and perform commit
      puts "DEBUG: Creating orchestrator"
      @orchestrator = Orchestrator.new(@generated_app)
      puts "DEBUG: App status before create_initial_commit: #{@generated_app.status}"

      puts "DEBUG: Creating initial commit"
      @orchestrator.create_initial_commit
      puts "DEBUG: App status after create_initial_commit: #{@generated_app.status}"

      # Verify final state
      assert_equal "generating_rails_app", @generated_app.status
    end

    test "handles errors during initial commit creation" do
      error_message = "Failed to create initial commit"
      error = StandardError.new(error_message)
      begin
        raise error
      rescue => error
        # Now error has a backtrace
      end

      # Set up logger
      @logger = AppGeneration::Logger.new(@generated_app.app_status)
      AppGeneration::Logger.expects(:new).with(@generated_app.app_status).returns(@logger).once

      # Set up app status to be ready for commit
      @generated_app.app_status.start_github_repo_creation!
      @generated_app.app_status.start_rails_app_generation!
      puts "DEBUG: App status after setup: #{@generated_app.status}"

      # Mock repository service to fail
      repository_service = mock("repository_service")
      repository_service.expects(:create_initial_commit).raises(error)
      AppRepositoryService.expects(:new).with(@generated_app, @logger).returns(repository_service)

      # Mock command execution service to prevent Rails new validation
      command_service = mock("command_service")
      CommandExecutionService.expects(:new).with(@generated_app, @logger).returns(command_service)

      # Expect proper logging
      sequence = sequence("error_logging")
      @logger.expects(:info).with("Starting app generation workflow").in_sequence(sequence)
      @logger.expects(:info).with("Creating initial commit").in_sequence(sequence)
      @logger.expects(:error).with("App generation failed", {
        error: error_message,
        backtrace: kind_of(String)
      }).in_sequence(sequence)

      # Create orchestrator and attempt commit
      puts "DEBUG: Creating orchestrator"
      @orchestrator = Orchestrator.new(@generated_app)
      puts "DEBUG: App status before create_initial_commit: #{@generated_app.status}"

      assert_raises(StandardError) do
        puts "DEBUG: Creating initial commit"
        @orchestrator.create_initial_commit
      rescue => e
        puts "DEBUG: Handling error: #{e.message}"
        puts "DEBUG: App status before handle_error: #{@generated_app.status}"
        @orchestrator.handle_error(e)
        puts "DEBUG: App status after handle_error: #{@generated_app.status}"
        raise
      end

      # Verify final state
      puts "DEBUG: Final app status before assertions: #{@generated_app.status}"
      assert_equal "failed", @generated_app.status
      assert_equal error_message, @generated_app.error_message
    end

    test "successfully pushes to remote" do
      # Set up logger
      @logger = AppGeneration::Logger.new(@generated_app.app_status)
      AppGeneration::Logger.expects(:new).with(@generated_app.app_status).returns(@logger).once

      # Set up app status to be ready for push
      @generated_app.app_status.start_github_repo_creation!
      @generated_app.app_status.start_rails_app_generation!
      puts "DEBUG: App status after setup: #{@generated_app.status}"

      # Mock repository service
      repository_service = mock("repository_service")
      repository_service.expects(:push_to_remote).once.returns(true)
      AppRepositoryService.expects(:new).with(@generated_app, @logger).returns(repository_service)

      # Mock command execution service to prevent Rails new validation
      command_service = mock("command_service")
      CommandExecutionService.expects(:new).with(@generated_app, @logger).returns(command_service)

      # Expect proper logging
      sequence = sequence("push_logging")
      @logger.expects(:info).with("Starting app generation workflow").in_sequence(sequence)
      @logger.expects(:info).with("Starting GitHub push").in_sequence(sequence)
      @logger.expects(:info).with("GitHub push completed successfully").in_sequence(sequence)

      # Create orchestrator and perform push
      puts "DEBUG: Creating orchestrator"
      @orchestrator = Orchestrator.new(@generated_app)
      puts "DEBUG: App status before push_to_remote: #{@generated_app.status}"

      puts "DEBUG: Pushing to remote"
      @orchestrator.push_to_remote
      puts "DEBUG: App status after push_to_remote: #{@generated_app.status}"

      # Verify final state
      assert_equal "pushing_to_github", @generated_app.status
    end

    test "handles errors during push to remote" do
      error_message = "Failed to push to remote"
      error = StandardError.new(error_message)
      begin
        raise error
      rescue => error
        # Now error has a backtrace
      end

      # Set up logger
      @logger = AppGeneration::Logger.new(@generated_app.app_status)
      AppGeneration::Logger.expects(:new).with(@generated_app.app_status).returns(@logger).once

      # Set up app status to be ready for push
      @generated_app.app_status.start_github_repo_creation!
      @generated_app.app_status.start_rails_app_generation!
      puts "DEBUG: App status after setup: #{@generated_app.status}"

      # Mock repository service to fail
      repository_service = mock("repository_service")
      repository_service.expects(:push_to_remote).raises(error)
      AppRepositoryService.expects(:new).with(@generated_app, @logger).returns(repository_service)

      # Mock command execution service to prevent Rails new validation
      command_service = mock("command_service")
      CommandExecutionService.expects(:new).with(@generated_app, @logger).returns(command_service)

      # Expect proper logging
      sequence = sequence("error_logging")
      @logger.expects(:info).with("Starting app generation workflow").in_sequence(sequence)
      @logger.expects(:info).with("Starting GitHub push").in_sequence(sequence)
      @logger.expects(:error).with("App generation failed", {
        error: error_message,
        backtrace: kind_of(String)
      }).in_sequence(sequence)

      # Create orchestrator and attempt push
      puts "DEBUG: Creating orchestrator"
      @orchestrator = Orchestrator.new(@generated_app)
      puts "DEBUG: App status before push_to_remote: #{@generated_app.status}"

      assert_raises(StandardError) do
        puts "DEBUG: Pushing to remote"
        @orchestrator.push_to_remote
      rescue => e
        puts "DEBUG: Handling error: #{e.message}"
        puts "DEBUG: App status before handle_error: #{@generated_app.status}"
        @orchestrator.handle_error(e)
        puts "DEBUG: App status after handle_error: #{@generated_app.status}"
        raise
      end

      # Verify final state
      puts "DEBUG: Final app status before assertions: #{@generated_app.status}"
      assert_equal "failed", @generated_app.status
      assert_equal error_message, @generated_app.error_message
    end

    test "successfully starts CI" do
      # Set up logger
      @logger = AppGeneration::Logger.new(@generated_app.app_status)
      AppGeneration::Logger.expects(:new).with(@generated_app.app_status).returns(@logger).once

      # Set up app status to be ready for CI
      @generated_app.app_status.start_github_repo_creation!
      @generated_app.app_status.start_rails_app_generation!
      @generated_app.app_status.start_github_push!
      puts "DEBUG: App status after setup: #{@generated_app.status}"

      # Mock command execution service to prevent Rails new validation
      command_service = mock("command_service")
      CommandExecutionService.expects(:new).with(@generated_app, @logger).returns(command_service)

      # Mock repository service
      repository_service = mock("repository_service")
      AppRepositoryService.expects(:new).with(@generated_app, @logger).returns(repository_service)

      # Expect proper logging
      sequence = sequence("ci_logging")
      @logger.expects(:info).with("Starting app generation workflow").in_sequence(sequence)
      @logger.expects(:info).with("Starting CI").in_sequence(sequence)
      @logger.expects(:info).with("CI started successfully").in_sequence(sequence)

      # Create orchestrator and start CI
      puts "DEBUG: Creating orchestrator"
      @orchestrator = Orchestrator.new(@generated_app)
      puts "DEBUG: App status before start_ci: #{@generated_app.status}"

      puts "DEBUG: Starting CI"
      @orchestrator.start_ci
      puts "DEBUG: App status after start_ci: #{@generated_app.status}"

      # Verify final state
      assert_equal "running_ci", @generated_app.status
    end

    test "handles errors during CI start" do
      error_message = "Failed to start CI"
      error = StandardError.new(error_message)
      begin
        raise error
      rescue => error
        # Now error has a backtrace
      end

      # Set up logger
      @logger = AppGeneration::Logger.new(@generated_app.app_status)
      AppGeneration::Logger.expects(:new).with(@generated_app.app_status).returns(@logger).once

      # Set up app status to be ready for CI
      @generated_app.app_status.start_github_repo_creation!
      @generated_app.app_status.start_rails_app_generation!
      @generated_app.app_status.start_github_push!
      puts "DEBUG: App status after setup: #{@generated_app.status}"

      # Mock command execution service to prevent Rails new validation
      command_service = mock("command_service")
      CommandExecutionService.expects(:new).with(@generated_app, @logger).returns(command_service)

      # Mock repository service
      repository_service = mock("repository_service")
      AppRepositoryService.expects(:new).with(@generated_app, @logger).returns(repository_service)

      # Mock start_ci to fail
      @generated_app.expects(:start_ci!).raises(error)

      # Expect proper logging
      sequence = sequence("error_logging")
      @logger.expects(:info).with("Starting app generation workflow").in_sequence(sequence)
      @logger.expects(:info).with("Starting CI").in_sequence(sequence)
      @logger.expects(:error).with("App generation failed", {
        error: error_message,
        backtrace: kind_of(String)
      }).in_sequence(sequence)

      # Create orchestrator and attempt to start CI
      puts "DEBUG: Creating orchestrator"
      @orchestrator = Orchestrator.new(@generated_app)
      puts "DEBUG: App status before start_ci: #{@generated_app.status}"

      assert_raises(StandardError) do
        puts "DEBUG: Starting CI"
        @orchestrator.start_ci
      rescue => e
        puts "DEBUG: Handling error: #{e.message}"
        puts "DEBUG: App status before handle_error: #{@generated_app.status}"
        @orchestrator.handle_error(e)
        puts "DEBUG: App status after handle_error: #{@generated_app.status}"
        raise
      end

      # Verify final state
      puts "DEBUG: Final app status before assertions: #{@generated_app.status}"
      assert_equal "failed", @generated_app.status
      assert_equal error_message, @generated_app.error_message
    end

    test "successfully completes generation" do
      # Set up logger
      @logger = AppGeneration::Logger.new(@generated_app.app_status)
      AppGeneration::Logger.expects(:new).with(@generated_app.app_status).returns(@logger).once

      # Set up app status to be ready for completion
      @generated_app.app_status.start_github_repo_creation!
      @generated_app.app_status.start_rails_app_generation!
      @generated_app.app_status.start_github_push!
      @generated_app.app_status.start_ci!
      puts "DEBUG: App status after setup: #{@generated_app.status}"

      # Mock command execution service to prevent Rails new validation
      command_service = mock("command_service")
      CommandExecutionService.expects(:new).with(@generated_app, @logger).returns(command_service)

      # Mock repository service
      repository_service = mock("repository_service")
      AppRepositoryService.expects(:new).with(@generated_app, @logger).returns(repository_service)

      # Expect proper logging
      sequence = sequence("completion_logging")
      @logger.expects(:info).with("Starting app generation workflow").in_sequence(sequence)
      @logger.expects(:info).with("Completing app generation").in_sequence(sequence)
      @logger.expects(:info).with("App generation completed successfully").in_sequence(sequence)

      # Create orchestrator and complete generation
      puts "DEBUG: Creating orchestrator"
      @orchestrator = Orchestrator.new(@generated_app)
      puts "DEBUG: App status before complete_generation: #{@generated_app.status}"

      puts "DEBUG: Completing generation"
      @orchestrator.complete_generation
      puts "DEBUG: App status after complete_generation: #{@generated_app.status}"

      # Verify final state
      assert_equal "completed", @generated_app.status
    end

    test "handles errors during generation completion" do
      error_message = "Failed to complete generation"
      error = StandardError.new(error_message)
      begin
        raise error
      rescue => error
        # Now error has a backtrace
      end

      # Set up logger
      @logger = AppGeneration::Logger.new(@generated_app.app_status)
      AppGeneration::Logger.expects(:new).with(@generated_app.app_status).returns(@logger).once

      # Set up app status to be ready for completion
      @generated_app.app_status.start_github_repo_creation!
      @generated_app.app_status.start_rails_app_generation!
      @generated_app.app_status.start_github_push!
      @generated_app.app_status.start_ci!
      puts "DEBUG: App status after setup: #{@generated_app.status}"

      # Mock command execution service to prevent Rails new validation
      command_service = mock("command_service")
      CommandExecutionService.expects(:new).with(@generated_app, @logger).returns(command_service)

      # Mock repository service
      repository_service = mock("repository_service")
      AppRepositoryService.expects(:new).with(@generated_app, @logger).returns(repository_service)

      # Mock complete! to fail
      @generated_app.expects(:complete!).raises(error)

      # Expect proper logging
      sequence = sequence("error_logging")
      @logger.expects(:info).with("Starting app generation workflow").in_sequence(sequence)
      @logger.expects(:info).with("Completing app generation").in_sequence(sequence)
      @logger.expects(:error).with("App generation failed", {
        error: error_message,
        backtrace: kind_of(String)
      }).in_sequence(sequence)

      # Create orchestrator and attempt completion
      puts "DEBUG: Creating orchestrator"
      @orchestrator = Orchestrator.new(@generated_app)
      puts "DEBUG: App status before complete_generation: #{@generated_app.status}"

      assert_raises(StandardError) do
        puts "DEBUG: Completing generation"
        @orchestrator.complete_generation
      rescue => e
        puts "DEBUG: Handling error: #{e.message}"
        puts "DEBUG: App status before handle_error: #{@generated_app.status}"
        @orchestrator.handle_error(e)
        puts "DEBUG: App status after handle_error: #{@generated_app.status}"
        raise
      end

      # Verify final state
      puts "DEBUG: Final app status before assertions: #{@generated_app.status}"
      assert_equal "failed", @generated_app.status
      assert_equal error_message, @generated_app.error_message
    end
  end
end
