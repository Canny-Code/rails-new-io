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

    # Save original BUNDLE_GEMFILE
    @original_bundle_gemfile = ENV["BUNDLE_GEMFILE"]
    # Set BUNDLE_GEMFILE to match the test app's Gemfile
    ENV["BUNDLE_GEMFILE"] = File.join(@app_directory, "Gemfile")
  end

  teardown do
    # Restore original BUNDLE_GEMFILE
    ENV["BUNDLE_GEMFILE"] = @original_bundle_gemfile
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

    # Mock all File.exist? calls
    File.stubs(:exist?).returns(true)
    File.stubs(:exist?).with(template_path).returns(true)

    # Mock LocalGitService to track the working directory
    git_service = LocalGitService.new(
      working_directory: @app_directory,
      logger: @logger
    )
    git_service.stubs(:in_working_directory).yields
    LocalGitService.stubs(:new).returns(git_service)

    # Mock Dir.pwd to return app directory
    Dir.stubs(:pwd).returns(@app_directory)

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
    expected_gemfile_path = File.join(@app_directory, "Gemfile")

    # Mock LocalGitService to track the working directory
    git_service = LocalGitService.new(
      working_directory: @app_directory,
      logger: @logger
    )
    git_service.stubs(:in_working_directory).yields
    LocalGitService.stubs(:new).returns(git_service)

    # Mock Dir.pwd to return the app directory
    Dir.stubs(:pwd).returns(@app_directory)

    # Use a block to temporarily override ENV
    original_bundle_gemfile = ENV["BUNDLE_GEMFILE"]
    begin
      # Set BUNDLE_GEMFILE to the expected path since we now validate before setting
      ENV["BUNDLE_GEMFILE"] = expected_gemfile_path
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

  test "fails when Gemfile does not exist" do
    configuration = { "auth_type" => "devise" }
    template_path = DataRepositoryService.new(user: @user).template_path(@ingredient)

    # Mock all File.exist? calls
    File.stubs(:exist?).returns(false)
    File.stubs(:exist?).with(template_path).returns(true)

    # Set up error logging expectations
    @logger.unstub(:error)
    @logger.expects(:error).with(
      "Bundler environment not properly set",
      has_entries(
        bundle_gemfile: regexp_matches(/Gemfile\z/),
        gemfile_exists: false
      )
    ).once

    @logger.expects(:error).with(
      "Failed to apply ingredient",
      has_entries(
        error: "Bundler environment not properly set",
        backtrace: anything,
        pwd: anything
      )
    ).once

    assert_raises(RuntimeError, "Bundler environment not properly set") do
      @generated_app.send(:apply_ingredient, @ingredient, configuration)
    end
  end

  test "fails when BUNDLE_GEMFILE is incorrect" do
    configuration = { "auth_type" => "devise" }
    template_path = "/path/to/template.rb"
    gemfile_path = File.join(@app_directory, "Gemfile")
    # Mock template path
    DataRepositoryService.any_instance.stubs(:template_path).returns(template_path)

    # Mock Dir.pwd first to return app directory
    Dir.stubs(:pwd).returns(@app_directory)

    # Mock all File.exist? calls
    File.stubs(:exist?).returns(true)
    File.stubs(:exist?).with(template_path).returns(true)
    File.stubs(:exist?).with(gemfile_path).returns(true)
    File.stubs(:exist?).with("Gemfile").returns(true)

    # Mock LocalGitService to track the working directory
    git_service = LocalGitService.new(
      working_directory: @app_directory,
      logger: @logger
    )
    git_service.stubs(:in_working_directory).yields
    LocalGitService.stubs(:new).returns(git_service)

    # Save original BUNDLE_GEMFILE
    original_bundle_gemfile = ENV["BUNDLE_GEMFILE"]
    begin
      # Set wrong BUNDLE_GEMFILE path - use a completely different path
      wrong_path = "/completely/different/path/Gemfile"
      ENV["BUNDLE_GEMFILE"] = wrong_path

      @logger.unstub(:error)
      @logger.expects(:error).with(
        "Bundler environment not properly set",
        has_entries(
          bundle_gemfile: wrong_path,
          gemfile_exists: true
        )
      ).once

      @logger.expects(:error).with(
        "Failed to apply ingredient",
        has_entries(
          error: "Bundler environment not properly set",
          backtrace: anything,
          pwd: anything
        )
      ).once

      assert_raises(RuntimeError, "Bundler environment not properly set") do
        @generated_app.send(:apply_ingredient, @ingredient, configuration)
      end
    ensure
      ENV["BUNDLE_GEMFILE"] = original_bundle_gemfile
    end
  end
end
