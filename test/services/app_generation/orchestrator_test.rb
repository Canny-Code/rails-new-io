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
      # Reset to initial state
      @generated_app.app_status.update!(status: "pending")

      # Stub Turbo Stream broadcasts and helpers
      Turbo::StreamsChannel.stubs(:broadcast_update_to)
      ApplicationController.helpers.stubs(:turbo_stream_from)

      # Set up logger
      @logger = AppGeneration::Logger.new(@generated_app.app_status)
      AppGeneration::Logger.expects(:new).with(@generated_app.app_status).returns(@logger).once

      # Set up logging sequence
      sequence = sequence("generation_logging")
      @logger.expects(:info).with("Starting app generation workflow").in_sequence(sequence)
      @logger.expects(:info).with("Starting GitHub repo creation").in_sequence(sequence)
      @logger.expects(:info).with("GitHub repo #{@generated_app.name} created successfully").in_sequence(sequence)
      @logger.expects(:info).with("Rails app generation process finished successfully", {
        command: @generated_app.command,
        app_name: @generated_app.name
      }).in_sequence(sequence)
      @logger.expects(:info).with("Applying ingredients", { count: 2 }).in_sequence(sequence)
      @logger.expects(:info).with("All ingredients applied successfully").in_sequence(sequence)

      # Mock repository service
      repository_service = mock("repository_service")
      repository_service.expects(:create_github_repository).once.returns(true)
      AppRepositoryService.expects(:new).with(@generated_app, @logger).returns(repository_service)

      # Mock command execution for rails new
      command_service = mock("command_service")
      command_service.expects(:execute).once.returns(true)
      CommandExecutionService.expects(:new).with(@generated_app, @logger).returns(command_service)

      # Mock template path verification
      data_repository = mock("data_repository")
      data_repository.stubs(:template_path).returns("path/to/template.rb")
      data_repository.stubs(:class).returns(DataRepositoryService)
      DataRepositoryService.stubs(:new).with(user: @generated_app.user).returns(data_repository)

      # Stub File.exist? for all possible paths
      File.stubs(:exist?).returns(false)
      File.stubs(:exist?).with("path/to/template.rb").returns(true)
      File.stubs(:exist?).with(regexp_matches(/config\/routes\.rb\z/)).returns(true)

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

      # Mock apply_ingredients
      @generated_app.expects(:apply_ingredients).once.returns(true)

      @orchestrator = Orchestrator.new(@generated_app)
      @orchestrator.create_github_repository
      @orchestrator.generate_rails_app
      @orchestrator.apply_ingredients

      assert_equal "applying_ingredients", @generated_app.status
    end

    test "handles missing template files during generation" do
      error_message = "Template file not found: /nonexistent/path/template.rb"

      # Reset to initial state
      @generated_app.app_status.update!(status: "pending")

      # Set up logger
      @logger = AppGeneration::Logger.new(@generated_app.app_status)
      AppGeneration::Logger.expects(:new).with(@generated_app.app_status).returns(@logger).once

      # Mock repository service
      repository_service = mock("repository_service")
      repository_service.expects(:create_github_repository).once.returns(true)
      AppRepositoryService.expects(:new).with(@generated_app, @logger).returns(repository_service)

      # Mock command execution
      command_service = mock("command_service")
      command_service.expects(:execute).once.returns(true)
      CommandExecutionService.expects(:new).with(@generated_app, @logger).returns(command_service)

      # Mock ingredient setup
      ingredient = ingredients(:rails_authentication)
      @generated_app.stubs(:ingredients).returns([ ingredient ])
      @generated_app.expects(:apply_ingredients).raises(StandardError.new(error_message))

      # Mock template path verification to fail
      data_repository = mock("data_repository")
      data_repository.stubs(:template_path).returns("/nonexistent/path/template.rb")
      DataRepositoryService.stubs(:new).with(user: @generated_app.user).returns(data_repository)
      # Stub all File.exist? calls to return false by default
      File.stubs(:exist?).returns(false)
      # Then override specific paths we care about
      File.stubs(:exist?).with("/nonexistent/path/template.rb").returns(false)
      File.stubs(:exist?).with(regexp_matches(/config\/routes\.rb\z/)).returns(false)

      # Expect proper logging
      sequence = sequence("error_logging")
      @logger.expects(:info).with("Starting app generation workflow").in_sequence(sequence)
      @logger.expects(:info).with("Starting GitHub repo creation").in_sequence(sequence)
      @logger.expects(:info).with("GitHub repo #{@generated_app.name} created successfully").in_sequence(sequence)
      @logger.expects(:info).with("Rails app generation process finished successfully", {
        command: @generated_app.command,
        app_name: @generated_app.name
      }).in_sequence(sequence)
      @logger.expects(:info).with("Applying ingredients", { count: 1 }).in_sequence(sequence)
      @logger.expects(:error).with("App generation failed", {
        error: error_message,
        backtrace: kind_of(String)
      }).in_sequence(sequence)

      @orchestrator = Orchestrator.new(@generated_app)
      @orchestrator.create_github_repository
      @orchestrator.generate_rails_app

      assert_raises(StandardError) do
        @orchestrator.apply_ingredients
      rescue => e
        @orchestrator.handle_error(e)
        raise
      end

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
      repository_service.expects(:create_github_repository).once.returns(true)
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
      @logger.expects(:error).with("App generation failed", {
        error: error_message,
        backtrace: kind_of(String)
      }).in_sequence(sequence)

      # Create orchestrator and perform generation
      @orchestrator = Orchestrator.new(@generated_app)
      @orchestrator.create_github_repository

      assert_raises(StandardError) do
        @orchestrator.generate_rails_app
      rescue => e
        @orchestrator.handle_error(e)
        raise
      end

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

      # Reset to initial state
      @generated_app.app_status.update!(status: "pending")

      # Set up logger
      @logger = AppGeneration::Logger.new(@generated_app.app_status)
      AppGeneration::Logger.expects(:new).with(@generated_app.app_status).returns(@logger).once

      # Mock command execution
      command_service = mock("command_service")
      command_service.expects(:execute).once.returns(true)
      CommandExecutionService.expects(:new).with(@generated_app, @logger).returns(command_service)

      # Mock repository service
      repository_service = mock("repository_service")
      repository_service.expects(:create_github_repository).once.returns(true)
      AppRepositoryService.expects(:new).with(@generated_app, @logger).returns(repository_service)

      # Expect proper logging
      sequence = sequence("error_logging")
      @logger.expects(:info).with("Starting app generation workflow").in_sequence(sequence)
      @logger.expects(:info).with("Starting GitHub repo creation").in_sequence(sequence)
      @logger.expects(:info).with("GitHub repo #{@generated_app.name} created successfully").in_sequence(sequence)
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
      @generated_app.expects(:apply_ingredients).raises(error)

      @orchestrator = Orchestrator.new(@generated_app)
      @orchestrator.create_github_repository
      @orchestrator.generate_rails_app

      assert_raises(StandardError) do
        @orchestrator.apply_ingredients
      rescue => e
        @orchestrator.handle_error(e)
        raise
      end
      assert_equal "failed", @generated_app.status
      assert_equal error_message, @generated_app.error_message
    end

    test "performs generation with actual ingredients" do
      # Reset to initial state
      @generated_app.app_status.update!(status: "pending")

      # Set up logger
      @logger = AppGeneration::Logger.new(@generated_app.app_status)
      AppGeneration::Logger.expects(:new).with(@generated_app.app_status).returns(@logger).once

      # Mock repository service
      repository_service = mock("repository_service")
      repository_service.expects(:create_github_repository).once.returns(true)
      AppRepositoryService.stubs(:new).with(@generated_app, @logger).returns(repository_service)

      # Mock command execution
      command_service = mock("command_service")
      command_service.expects(:execute).once.returns(true)
      CommandExecutionService.expects(:new).with(@generated_app, @logger).returns(command_service)

      # Mock template path verification
      data_repository = mock("data_repository")
      data_repository.stubs(:template_path).returns("path/to/template.rb")
      data_repository.stubs(:class).returns(DataRepositoryService)
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

      # Set up logging sequence
      sequence = sequence("generation_logging")
      @logger.expects(:info).with("Starting app generation workflow").in_sequence(sequence)
      @logger.expects(:info).with("Starting GitHub repo creation").in_sequence(sequence)
      @logger.expects(:info).with("GitHub repo #{@generated_app.name} created successfully").in_sequence(sequence)
      @logger.expects(:info).with("Rails app generation process finished successfully", {
        command: @generated_app.command,
        app_name: @generated_app.name
      }).in_sequence(sequence)
      @logger.expects(:info).with("Applying ingredients", { count: 2 }).in_sequence(sequence)
      @logger.expects(:info).with("All ingredients applied successfully").in_sequence(sequence)

      # Mock apply_ingredients to succeed
      @generated_app.expects(:apply_ingredients).once.returns(true)

      @orchestrator = Orchestrator.new(@generated_app)
      @orchestrator.create_github_repository
      @orchestrator.generate_rails_app
      @orchestrator.apply_ingredients
      assert_equal "applying_ingredients", @generated_app.status
    end

    test "successfully creates initial commit" do
      # Reset to initial state
      @generated_app.app_status.update!(status: "pending")

      # Clean up any existing ingredients
      @generated_app.recipe.recipe_ingredients.destroy_all

      # Set up logger
      @logger = AppGeneration::Logger.new(@generated_app.app_status)
      AppGeneration::Logger.expects(:new).with(@generated_app.app_status).returns(@logger).once

      # Mock repository service for initial creation
      repository_service = mock("repository_service")
      repository_service.expects(:create_github_repository).once.returns(true)
      repository_service.expects(:create_initial_commit).once.returns(true)
      AppRepositoryService.expects(:new).with(@generated_app, @logger).returns(repository_service)

      # Mock command execution service
      command_service = mock("command_service")
      command_service.expects(:execute).once.returns(true)
      CommandExecutionService.expects(:new).with(@generated_app, @logger).returns(command_service)

      # Mock apply_ingredients
      @generated_app.expects(:apply_ingredients).once.returns(true)

      # Expect proper logging
      sequence = sequence("commit_logging")
      @logger.expects(:info).with("Starting app generation workflow").in_sequence(sequence)
      @logger.expects(:info).with("Starting GitHub repo creation").in_sequence(sequence)
      @logger.expects(:info).with("GitHub repo #{@generated_app.name} created successfully").in_sequence(sequence)
      @logger.expects(:info).with("Rails app generation process finished successfully", {
        command: @generated_app.command,
        app_name: @generated_app.name
      }).in_sequence(sequence)
      @logger.expects(:info).with("Applying ingredients", { count: 0 }).in_sequence(sequence)
      @logger.expects(:info).with("All ingredients applied successfully").in_sequence(sequence)
      @logger.expects(:info).with("Creating initial commit").in_sequence(sequence)
      @logger.expects(:info).with("Initial commit created successfully").in_sequence(sequence)

      @orchestrator = Orchestrator.new(@generated_app)
      @orchestrator.create_github_repository
      @orchestrator.generate_rails_app
      @orchestrator.apply_ingredients
      @orchestrator.create_initial_commit

      assert_equal "applying_ingredients", @generated_app.status
    end

    test "handles errors during initial commit creation" do
      # Reset to initial state
      @generated_app.app_status.update!(status: "pending")

      # Clean up any existing ingredients
      @generated_app.recipe.recipe_ingredients.destroy_all

      # Set up logger
      @logger = AppGeneration::Logger.new(@generated_app.app_status)
      AppGeneration::Logger.expects(:new).with(@generated_app.app_status).returns(@logger).once

      error_message = "Failed to create initial commit"
      error = StandardError.new(error_message)
      begin
        raise error
      rescue => error
        # Now error has a backtrace
      end

      # Mock repository service
      repository_service = mock("repository_service")
      repository_service.expects(:create_github_repository).once.returns(true)
      repository_service.expects(:create_initial_commit).raises(error)
      AppRepositoryService.expects(:new).with(@generated_app, @logger).returns(repository_service)

      # Mock command execution service
      command_service = mock("command_service")
      command_service.expects(:execute).once.returns(true)
      CommandExecutionService.expects(:new).with(@generated_app, @logger).returns(command_service)

      # Mock apply_ingredients
      @generated_app.expects(:apply_ingredients).once.returns(true)

      # Expect proper logging
      sequence = sequence("error_logging")
      @logger.expects(:info).with("Starting app generation workflow").in_sequence(sequence)
      @logger.expects(:info).with("Starting GitHub repo creation").in_sequence(sequence)
      @logger.expects(:info).with("GitHub repo #{@generated_app.name} created successfully").in_sequence(sequence)
      @logger.expects(:info).with("Rails app generation process finished successfully", {
        command: @generated_app.command,
        app_name: @generated_app.name
      }).in_sequence(sequence)
      @logger.expects(:info).with("Applying ingredients", { count: 0 }).in_sequence(sequence)
      @logger.expects(:info).with("All ingredients applied successfully").in_sequence(sequence)
      @logger.expects(:info).with("Creating initial commit").in_sequence(sequence)
      @logger.expects(:error).with("App generation failed", {
        error: error_message,
        backtrace: kind_of(String)
      }).in_sequence(sequence)

      @orchestrator = Orchestrator.new(@generated_app)
      @orchestrator.create_github_repository
      @orchestrator.generate_rails_app
      @orchestrator.apply_ingredients

      assert_raises(StandardError) do
        @orchestrator.create_initial_commit
      rescue => e
        @orchestrator.handle_error(e)
        raise
      end

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
      @generated_app.app_status.start_ingredient_application!

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

      @orchestrator = Orchestrator.new(@generated_app)
      @orchestrator.push_to_remote

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
      @generated_app.app_status.start_ingredient_application!

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

      @orchestrator = Orchestrator.new(@generated_app)

      assert_raises(StandardError) do
        @orchestrator.push_to_remote
      rescue => e
        @orchestrator.handle_error(e)
        raise
      end

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
      @generated_app.app_status.start_ingredient_application!
      @generated_app.app_status.start_github_push!

      # Mock command execution service to prevent Rails new validation
      command_service = mock("command_service")
      CommandExecutionService.expects(:new).with(@generated_app, @logger).returns(command_service)

      # Mock repository service
      repository_service = mock("repository_service")
      AppRepositoryService.expects(:new).with(@generated_app, @logger).returns(repository_service)

      # Expect proper logging
      sequence = sequence("ci_logging")
      @logger.expects(:info).with("Starting app generation workflow").in_sequence(sequence)
      @logger.expects(:info).with("Starting CI run").in_sequence(sequence)

      @orchestrator = Orchestrator.new(@generated_app)
      @orchestrator.start_ci

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
      @generated_app.app_status.start_ingredient_application!
      @generated_app.app_status.start_github_push!

      command_service = mock("command_service")
      CommandExecutionService.expects(:new).with(@generated_app, @logger).returns(command_service)

      repository_service = mock("repository_service")
      AppRepositoryService.expects(:new).with(@generated_app, @logger).returns(repository_service)

      # Set up logging sequence
      sequence = sequence("error_logging")
      @logger.expects(:info).with("Starting app generation workflow").in_sequence(sequence)
      @generated_app.expects(:start_ci!).raises(error).in_sequence(sequence)
      @logger.expects(:error).with("App generation failed", {
        error: error_message,
        backtrace: kind_of(String)
      }).in_sequence(sequence)

      @orchestrator = Orchestrator.new(@generated_app)

      assert_raises(StandardError) do
        @orchestrator.start_ci
      rescue => e
        @orchestrator.handle_error(e)
        raise
      end

      assert_equal "failed", @generated_app.status
      assert_equal error_message, @generated_app.error_message
    end

    test "successfully completes generation" do
      # Reset to initial state
      @generated_app.app_status.update!(status: "running_ci")

      # Set up logger
      @logger = AppGeneration::Logger.new(@generated_app.app_status)
      AppGeneration::Logger.expects(:new).with(@generated_app.app_status).returns(@logger).once

      # Mock command execution service
      command_service = mock("command_service")
      CommandExecutionService.expects(:new).with(@generated_app, @logger).returns(command_service)

      # Mock repository service
      repository_service = mock("repository_service")
      AppRepositoryService.expects(:new).with(@generated_app, @logger).returns(repository_service)

      # Expect proper logging
      sequence = sequence("completion_logging")
      @logger.expects(:info).with("Starting app generation workflow").in_sequence(sequence)
      @logger.expects(:info).with("App generation completed successfully").in_sequence(sequence)

      @orchestrator = Orchestrator.new(@generated_app)
      @orchestrator.complete_generation

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
      @generated_app.app_status.update!(status: "running_ci")

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
      @logger.expects(:error).with("App generation failed", {
        error: error_message,
        backtrace: kind_of(String)
      }).in_sequence(sequence)

      @orchestrator = Orchestrator.new(@generated_app)

      assert_raises(StandardError) do
        @orchestrator.complete_generation
      rescue => e
        @orchestrator.handle_error(e)
        raise
      end

      assert_equal "failed", @generated_app.status
      assert_equal error_message, @generated_app.error_message
    end

    test "log entries have correct icons throughout the workflow" do
      # Reset to initial state
      @generated_app.app_status.update!(status: "pending")

      # Set up logger
      @logger = AppGeneration::Logger.new(@generated_app.app_status)
      @generated_app.logger = @logger

      # Clean up any existing ingredients and add test ingredients
      @generated_app.recipe.recipe_ingredients.destroy_all
      ingredient1 = ingredients(:rails_authentication)
      ingredient2 = ingredients(:api_setup)
      @generated_app.recipe.add_ingredient!(ingredient1)
      @generated_app.recipe.add_ingredient!(ingredient2)

      # Mock repository service
      repository_service = mock("repository_service")
      repository_service.stubs(:create_github_repository).returns(true)
      repository_service.stubs(:create_initial_commit).returns(true)
      repository_service.stubs(:push_to_remote).returns(true)
      repository_service.stubs(:commit_changes_after_applying_ingredient).returns(true)

      AppRepositoryService.stubs(:new).returns(repository_service)
      @generated_app.stubs(:repository_service).returns(repository_service)

      output = "Sample output"
      error = "Sample error"

      # Stub all Open3.popen3 calls for the entire test
      Open3.stubs(:popen3).yields(
        StringIO.new,
        StringIO.new(output),
        StringIO.new(error),
        Data.define(:pid, :value).new(
          pid: 12345,
          value: Data.define(:success?).new(success?: true)
        )
      )

      github_service = mock("github_service")
      github_service.stubs(:commit_changes).returns(true)
      github_service.stubs(:write_recipe).returns(true)
      github_service.stubs(:template_path).returns("path/to/template.rb")
      GithubRepositoryService.stubs(:new).returns(github_service)

      # Mock LocalGitService
      local_git_service = mock("local_git_service")
      local_git_service.stubs(:in_working_directory).yields
      local_git_service.stubs(:commit_changes_after_applying_ingredient).returns(true)
      LocalGitService.stubs(:new).returns(local_git_service)

      File.stubs(:exist?).returns(false)
      File.stubs(:exist?).with("path/to/template.rb").returns(true)
      # Mock the Gemfile existence check
      File.stubs(:exist?).with(regexp_matches(/Gemfile\z/)).returns(true)

      @orchestrator = Orchestrator.new(@generated_app)

      # Execute the workflow
      @orchestrator.create_github_repository
      @orchestrator.generate_rails_app
      @orchestrator.create_initial_commit
      @orchestrator.apply_ingredients
      @orchestrator.install_dependencies
      @orchestrator.push_to_remote
      @orchestrator.start_ci
      @orchestrator.complete_generation

      # Verify log entries and their icons
      entries = @generated_app.log_entries.order(:created_at)
      # Starting workflow
      assert_match(/🛤️ 🏗️ 🔄 Starting app generation workflow/, entries[0].decorated_message)

      # GitHub repo creation
      assert_match(/🐙 🏗️ 🔄 Starting GitHub repo creation/, entries[1].decorated_message)

      # GitHub repo success
      assert_match(/🐙 🏗️ ✅ GitHub repo .+ created successfully/, entries[2].decorated_message)

      assert_match(/🛤️ 🛡️ 🔄 Validating command/, entries[3].decorated_message)
      assert_match(/🛤️ 🛡️ ✅ Command validation successful/, entries[4].decorated_message)
      assert_match(/💻 📂 ✅ Created workspace directory/, entries[5].decorated_message)
      assert_match(/💻 🛠️ ✅ Preparing to execute command/, entries[6].decorated_message)
      assert_match(/💻 📈 🔍 System environment details/, entries[7].decorated_message)
      assert_match(/💻 📈 🔍 Environment variables for command execution/, entries[8].decorated_message)

      # Rails app generation
      assert_match(/Executing command: `rails new/, entries[9].decorated_message)
      assert_match(/🛤️ 🏗️ 🔄 Command execution started/, entries[10].decorated_message)
      assert_match(/🛤️ 🏗️ ✅ Rails app generation process finished successfully/, entries[11].decorated_message)

      # Initial commit creation
      assert_match(/🐙 📝 🔄 Creating initial commit/, entries[12].decorated_message)
      assert_match(/🐙 📝 ✅ Initial commit created successfully/, entries[13].decorated_message)

      # Ingredient application
      assert_match(/🍱 🏗️ 🔄 Applying ingredients/, entries[14].decorated_message)

      # First ingredient
      assert_match(/🍱 🍣 🔄 Applying ingredient: Rails Authentication/, entries[15].decorated_message)
      assert_match(/🛤️ 🛡️ 🔄 Validating command/, entries[16].decorated_message)
      assert_match(/🛤️ 🛡️ ✅ Command validation successful/, entries[17].decorated_message)
      assert_match(/💻 📂 ✅ Using existing app directory/, entries[18].decorated_message)
      assert_match(/💻 🛠️ ✅ Preparing to execute command/, entries[19].decorated_message)
      assert_match(/💻 📈 🔍 System environment details/, entries[20].decorated_message)
      assert_match(/💻 📈 🔍 Environment variables for command execution/, entries[21].decorated_message)
      assert_match(%r{<p>Executing command: `./bin/rails app:template LOCATION=}, entries[22].decorated_message)
      assert_match(/🍱 🏗️ 🔄 Command execution started: rails app:template LOCATION/, entries[23].decorated_message)
      assert_match(/🐙 🍣 📝 Committing ingredient changes/, entries[24].decorated_message)
      assert_match(/🍱 🍣 ✅ Ingredient Rails Authentication applied successfully/, entries[25].decorated_message)

      # Second ingredient
      assert_match(/🍱 🍣 🔄 Applying ingredient: API Setup/, entries[26].decorated_message)
      assert_match(/🛤️ 🛡️ 🔄 Validating command/, entries[27].decorated_message)
      assert_match(/🛤️ 🛡️ ✅ Command validation successful/, entries[28].decorated_message)
      assert_match(/💻 📂 ✅ Using existing app directory/, entries[29].decorated_message)
      assert_match(/💻 🛠️ ✅ Preparing to execute command/, entries[30].decorated_message)
      assert_match(/💻 📈 🔍 System environment details/, entries[31].decorated_message)
      assert_match(/💻 📈 🔍 Environment variables for command execution/, entries[32].decorated_message)
      assert_match(%r{<p>Executing command: `./bin/rails app:template LOCATION=}, entries[33].decorated_message)
      assert_match(/🍱 🏗️ 🔄 Command execution started: rails app:template LOCATION/, entries[34].decorated_message)
      assert_match(/🐙 🍣 📝 Committing ingredient changes/, entries[35].decorated_message)
      assert_match(/🍱 🍣 ✅ Ingredient API Setup applied successfully/, entries[36].decorated_message)

      # All ingredients completed
      assert_match(/🍱 🏗️ ✅ All ingredients applied successfully/, entries[37].decorated_message)

      # Installing dependencies
      assert_match(/📦 🏗️ 🔄 Installing app dependencies/, entries[38].decorated_message)
      assert_match(/🛤️ 🛡️ 🔄 Validating command/, entries[39].decorated_message)
      assert_match(/🛤️ 🛡️ ✅ Command validation successful/, entries[40].decorated_message)
      assert_match(/💻 📂 ✅ Using existing app directory/, entries[41].decorated_message)
      assert_match(/💻 🛠️ ✅ Preparing to execute command/, entries[42].decorated_message)
      assert_match(/💻 📈 🔍 System environment details/, entries[43].decorated_message)
      assert_match(/💻 📈 🔍 Environment variables for command execution/, entries[44].decorated_message)
      assert_match(%r{<p>Executing command: `bundle install`}, entries[45].decorated_message)
      assert_match(/📦 🏗️ 🔄 Command execution started: bundle install/, entries[46].decorated_message)

      assert_match(/📦 🏗️ ✅ Dependencies installed successfully/, entries[47].decorated_message)

      # Push to remote
      assert_match(/🐙 ⬆️ 🔄 Starting GitHub push/, entries[48].decorated_message)
      assert_match(/🐙 ⬆️ ✅ GitHub push completed successfully/, entries[49].decorated_message)

      # CI run
      assert_match(/🐙 ⚙️ 🔄 Starting CI run/, entries[50].decorated_message)

      # Generation completed
      assert_match(/🛤️ 🏗️ ✅ App generation completed successfully/, entries[51].decorated_message)
    end
  end
end
