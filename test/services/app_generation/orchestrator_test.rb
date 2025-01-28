require "test_helper"
require_relative "../../../app/services/app_generation/errors"

module AppGeneration
  class OrchestratorTest < ActiveSupport::TestCase
    setup do
      @generated_app = generated_apps(:pending_app)
      @orchestrator = Orchestrator.new(@generated_app)
      @original_adapter = ActiveJob::Base.queue_adapter
      ActiveJob::Base.queue_adapter = :solid_queue
    end

    teardown do
      ActiveJob::Base.queue_adapter = @original_adapter
    end

    test "enqueues generation job when app is in pending state" do
      assert @generated_app.pending?

      assert_difference -> { SolidQueue::Job.count } do
        assert @orchestrator.enqueue_app_generation_job
      end

      job = SolidQueue::Job.last
      assert_equal "AppGenerationJob", job.class_name
      assert_equal [ @generated_app.id ], job.arguments["arguments"]
    end

    test "validates app must be in pending state" do
      @generated_app.app_status.update!(status: "generating")
      @generated_app.reload

      assert_equal "generating", @generated_app.status
      assert_not @generated_app.pending?

      error = assert_raises(AppGeneration::Errors::InvalidStateError) do
        @orchestrator.enqueue_app_generation_job
      end

      assert_equal "App must be in pending state to start generation", error.message
    end

    test "handles and logs errors during orchestration" do
      error_message = "Something went wrong"
      AppGenerationJob.stubs(:perform_later).raises(StandardError.new(error_message))

      # Expect both error logs in sequence
      sequence = sequence("error_logging")
      AppGeneration::Logger.any_instance.expects(:error).with(
        "Failed to start app generation",
        { error: error_message }
      ).in_sequence(sequence)
      AppGeneration::Logger.any_instance.expects(:error).with(
        "App generation failed: #{error_message}"
      ).in_sequence(sequence)

      assert_not @orchestrator.enqueue_app_generation_job
      assert @generated_app.reload.failed?
      assert_equal error_message, @generated_app.app_status.error_message
    end

    test "successfully performs app generation" do
      # Mock command execution
      command_service = mock("command_service")
      command_service.expects(:execute).once
      CommandExecutionService.expects(:new).with(@generated_app, @generated_app.command).returns(command_service)

      # Mock ingredient application
      ingredient = ingredients(:rails_authentication)
      @generated_app.stubs(:ingredients).returns([ ingredient ])

      # Mock template path verification
      data_repository = mock("data_repository")
      data_repository.stubs(:template_path).returns("path/to/template.rb")
      DataRepositoryService.stubs(:new).with(user: @generated_app.user).returns(data_repository)
      File.stubs(:exist?).with("path/to/template.rb").returns(true)

      # Expect the app to be marked as generating and ingredients to be applied
      @generated_app.expects(:generate!).once
      @generated_app.expects(:apply_ingredient!).with(ingredient).once

      # Expect proper logging
      sequence = sequence("generation_logging")
      AppGeneration::Logger.any_instance.expects(:info).with("Starting app generation").in_sequence(sequence)
      AppGeneration::Logger.any_instance.expects(:info).with("Executing Rails new command").in_sequence(sequence)
      AppGeneration::Logger.any_instance.expects(:info).with("Applying ingredients").in_sequence(sequence)
      AppGeneration::Logger.any_instance.expects(:info).with("Finished applying ingredient", { ingredient: ingredient.name }).in_sequence(sequence)
      AppGeneration::Logger.any_instance.expects(:info).with("App generation completed successfully").in_sequence(sequence)

      @orchestrator.generate_rails_app
    end

    test "handles missing template files during generation" do
      # Mock command execution
      command_service = mock("command_service")
      command_service.expects(:execute).once
      CommandExecutionService.expects(:new).with(@generated_app, @generated_app.command).returns(command_service)

      # Mock ingredient setup
      ingredient = ingredients(:rails_authentication)
      @generated_app.stubs(:ingredients).returns([ ingredient ])

      # Mock template path verification to fail
      data_repository = mock("data_repository")
      data_repository.stubs(:template_path).returns("/nonexistent/path/template.rb")
      DataRepositoryService.stubs(:new).with(user: @generated_app.user).returns(data_repository)
      File.stubs(:exist?).with("/nonexistent/path/template.rb").returns(false)

      # Expect proper state transitions and error handling
      @generated_app.expects(:generate!).once
      @generated_app.expects(:mark_as_failed!).with("Template file not found: /nonexistent/path/template.rb")

      # Expect proper logging
      sequence = sequence("error_logging")
      AppGeneration::Logger.any_instance.expects(:info).with("Starting app generation").in_sequence(sequence)
      AppGeneration::Logger.any_instance.expects(:info).with("Executing Rails new command").in_sequence(sequence)
      AppGeneration::Logger.any_instance.expects(:info).with("Applying ingredients").in_sequence(sequence)
      AppGeneration::Logger.any_instance.expects(:error).with("Template file not found", { path: "/nonexistent/path/template.rb" }).in_sequence(sequence)
      AppGeneration::Logger.any_instance.expects(:error).with("App generation failed", { error: "Template file not found: /nonexistent/path/template.rb" }).in_sequence(sequence)

      assert_raises(StandardError) do
        @orchestrator.generate_rails_app
      end
    end

    test "handles errors during rails new command" do
      error_message = "Rails new command failed"

      # Mock command execution to fail
      command_service = mock("command_service")
      command_service.expects(:execute).raises(StandardError.new(error_message))
      CommandExecutionService.expects(:new).with(@generated_app, @generated_app.command).returns(command_service)

      # Expect proper state transitions and error handling
      @generated_app.expects(:generate!).once
      @generated_app.expects(:mark_as_failed!).with(error_message)

      # Expect proper logging
      sequence = sequence("error_logging")
      AppGeneration::Logger.any_instance.expects(:info).with("Starting app generation").in_sequence(sequence)
      AppGeneration::Logger.any_instance.expects(:info).with("Executing Rails new command").in_sequence(sequence)
      AppGeneration::Logger.any_instance.expects(:error).with("App generation failed", { error: error_message }).in_sequence(sequence)

      assert_raises(StandardError) do
        @orchestrator.generate_rails_app
      end
    end

    test "handles errors during ingredient application" do
      error_message = "Failed to apply ingredient"

      # Mock command execution
      command_service = mock("command_service")
      command_service.expects(:execute).once
      CommandExecutionService.expects(:new).with(@generated_app, @generated_app.command).returns(command_service)

      # Mock ingredient setup
      ingredient = ingredients(:rails_authentication)
      @generated_app.stubs(:ingredients).returns([ ingredient ])

      # Mock template path verification
      data_repository = mock("data_repository")
      data_repository.stubs(:template_path).returns("path/to/template.rb")
      DataRepositoryService.stubs(:new).with(user: @generated_app.user).returns(data_repository)
      File.stubs(:exist?).with("path/to/template.rb").returns(true)

      # Mock ingredient application to fail
      @generated_app.expects(:generate!).once
      @generated_app.expects(:apply_ingredient!).with(ingredient).raises(StandardError.new(error_message))
      @generated_app.expects(:mark_as_failed!).with(error_message)

      # Expect proper logging
      sequence = sequence("error_logging")
      AppGeneration::Logger.any_instance.expects(:info).with("Starting app generation").in_sequence(sequence)
      AppGeneration::Logger.any_instance.expects(:info).with("Executing Rails new command").in_sequence(sequence)
      AppGeneration::Logger.any_instance.expects(:info).with("Applying ingredients").in_sequence(sequence)
      AppGeneration::Logger.any_instance.expects(:error).with("App generation failed", { error: error_message }).in_sequence(sequence)

      assert_raises(StandardError) do
        @orchestrator.generate_rails_app
      end
    end

    test "performs generation with actual ingredients" do
      # Mock command execution
      command_service = mock("command_service")
      command_service.expects(:execute).once
      CommandExecutionService.expects(:new).with(@generated_app, @generated_app.command).returns(command_service)

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

      # Expect the app to be marked as generating and ingredients to be applied
      @generated_app.expects(:generate!).once
      @generated_app.expects(:apply_ingredient!).with(ingredient1).once.returns(true)
      @generated_app.expects(:apply_ingredient!).with(ingredient2).once.returns(true)

      # Expect proper logging
      sequence = sequence("generation_logging")
      AppGeneration::Logger.any_instance.expects(:info).with("Starting app generation").in_sequence(sequence)
      AppGeneration::Logger.any_instance.expects(:info).with("Executing Rails new command").in_sequence(sequence)
      AppGeneration::Logger.any_instance.expects(:info).with("Applying ingredients").in_sequence(sequence)
      AppGeneration::Logger.any_instance.expects(:info).with("Finished applying ingredient", { ingredient: ingredient1.name }).in_sequence(sequence)
      AppGeneration::Logger.any_instance.expects(:info).with("Finished applying ingredient", { ingredient: ingredient2.name }).in_sequence(sequence)
      AppGeneration::Logger.any_instance.expects(:info).with("App generation completed successfully").in_sequence(sequence)

      # Perform generation
      @orchestrator.generate_rails_app

      # Verify final state
      assert_equal 2, @generated_app.recipe.recipe_ingredients.count
      assert_equal ingredient1.id, @generated_app.recipe.recipe_ingredients.first.ingredient_id
      assert_equal ingredient2.id, @generated_app.recipe.recipe_ingredients.last.ingredient_id
      assert_equal ingredient1.name, @generated_app.recipe.recipe_ingredients.first.ingredient.name
      assert_equal ingredient2.name, @generated_app.recipe.recipe_ingredients.last.ingredient.name
      assert_equal [ ingredient1.id, ingredient2.id ], @generated_app.recipe.ingredients.order(:position).pluck(:id)
      assert_equal [ 1, 2 ], @generated_app.recipe.recipe_ingredients.order(:position).pluck(:position)
    end
  end
end
