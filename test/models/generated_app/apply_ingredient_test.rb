require "test_helper"
require "rails/generators"
require "rails/generators/rails/app/app_generator"

class GeneratedApp::ApplyIngredientTest < ActiveSupport::TestCase
  include DisableParallelization

  setup do
    @user = users(:john)
    @recipe = recipes(:blog_recipe)
    @ingredient = ingredients(:rails_authentication)
    @generated_app = generated_apps(:blog_app)

    # Create test directories
    @workspace_path = create_test_directory("test_apps")
    @app_directory = File.join(@workspace_path, @generated_app.name)
    FileUtils.mkdir_p(@app_directory)
    FileUtils.touch(File.join(@app_directory, "Gemfile"))
    @generated_app.update!(workspace_path: @workspace_path)

    # Mock the logger to avoid actual logging
    @logger = mock("logger")
    @logger.stubs(:info)
    @logger.stubs(:error)
    @generated_app.logger = @logger
    AppGeneration::Logger.stubs(:new).returns(@logger)

    # Mock Rails generators
    @generator = mock("generator")
    @generator.stubs(:apply)
    Rails::Generators::AppGenerator.stubs(:new).returns(@generator)
  end

  test "successfully applies ingredient" do
    configuration = { "auth_type" => "devise" }

    # Ensure template exists
    template_path = DataRepositoryService.new(user: @user).template_path(@ingredient)
    FileUtils.mkdir_p(File.dirname(template_path))
    File.write(template_path, "# Test template")

    assert_difference -> { @recipe.recipe_changes.count }, 1 do
      assert_difference -> { @generated_app.app_changes.count }, 1 do
        @generated_app.send(:apply_ingredient, @ingredient, configuration)
      end
    end

    recipe_change = @recipe.recipe_changes.last
    app_change = @generated_app.app_changes.last

    assert_equal "add_ingredient", recipe_change.change_type
    assert_equal configuration, recipe_change.change_data["configuration"]
    assert_equal configuration, app_change.configuration
    assert_equal recipe_change, app_change.recipe_change
  end

  test "sets up correct generator configuration" do
    configuration = { "auth_type" => "devise" }
    template_path = "path/to/template.rb"

    DataRepositoryService.any_instance.stubs(:template_path).with(@ingredient).returns(template_path)
    @generator.expects(:apply).once

    Rails::Generators::AppGenerator.expects(:new).with(
      [ "." ],
      template: template_path,
      force: true,
      quiet: true,
      pretend: false,
      skip_bundle: true,
      auth_type: "devise"
    ).returns(@generator)

    File.expects(:exist?).with(template_path).returns(true)

    @generated_app.send(:apply_ingredient, @ingredient, configuration)
  end

  test "handles errors during application" do
    configuration = { "auth_type" => "devise" }
    error_message = "Something went wrong"
    error = StandardError.new(error_message)

    # Ensure template exists
    template_path = DataRepositoryService.new(user: @user).template_path(@ingredient)
    FileUtils.mkdir_p(File.dirname(template_path))
    File.write(template_path, "# Test template")

    # Set up the generator to raise error
    Rails::Generators::AppGenerator.stubs(:new).returns(@generator)
    @generator.expects(:apply).raises(error)

    # Set up error logging expectation
    @logger.unstub(:error)
    @logger.expects(:error).with(
      "Failed to apply ingredient",
      has_entries(
        error: error_message,
        backtrace: anything,
        pwd: anything
      )
    )

    assert_raises StandardError do
      @generated_app.send(:apply_ingredient, @ingredient, configuration)
    end
  end

  test "uses correct environment variables and paths" do
    configuration = { "auth_type" => "devise" }

    # Ensure template exists
    template_path = DataRepositoryService.new(user: @user).template_path(@ingredient)
    FileUtils.mkdir_p(File.dirname(template_path))
    File.write(template_path, "# Test template")

    # Track if BUNDLE_GEMFILE was set correctly
    bundle_gemfile_set = false
    expected_gemfile_path = File.join(@app_directory, "Gemfile")

    # Use a block to temporarily override ENV
    original_bundle_gemfile = ENV["BUNDLE_GEMFILE"]
    begin
      ENV["BUNDLE_GEMFILE"] = "wrong_path"
      @generated_app.send(:apply_ingredient, @ingredient, configuration)
      assert_equal expected_gemfile_path, ENV["BUNDLE_GEMFILE"], "BUNDLE_GEMFILE was not set correctly"
    ensure
      ENV["BUNDLE_GEMFILE"] = original_bundle_gemfile
    end
  end

  test "wraps operations in a transaction" do
    configuration = { "auth_type" => "devise" }
    error_message = "Transaction test"
    error = StandardError.new(error_message)

    # Ensure template exists
    template_path = DataRepositoryService.new(user: @user).template_path(@ingredient)
    FileUtils.mkdir_p(File.dirname(template_path))
    File.write(template_path, "# Test template")

    # Set up the generator to raise error
    Rails::Generators::AppGenerator.stubs(:new).returns(@generator)
    @generator.expects(:apply).raises(error)

    # Set up error logging expectation
    @logger.unstub(:error)
    @logger.expects(:error).with(
      "Failed to apply ingredient",
      has_entries(
        error: error_message,
        backtrace: anything,
        pwd: anything
      )
    )

    # Verify that the transaction rolls back by checking no records are created
    assert_no_difference -> { @recipe.recipe_changes.count } do
      assert_no_difference -> { @generated_app.app_changes.count } do
        assert_raises StandardError do
          @generated_app.send(:apply_ingredient, @ingredient, configuration)
        end
      end
    end
  end
end
