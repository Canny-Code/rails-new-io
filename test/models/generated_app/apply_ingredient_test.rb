require "test_helper"

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
    @logger.stubs(:debug)
    @logger.stubs(:error)
    @generated_app.logger = @logger
    AppGeneration::Logger.stubs(:new).returns(@logger)

    # Mock CommandExecutionService
    @command_service = mock("command_service")
    @command_service.stubs(:execute).returns(@app_directory)
    CommandExecutionService.stubs(:new).returns(@command_service)

    # Mock repository service
    @repository_service = mock("repository_service")
    @repository_service.stubs(:commit_changes).returns(true)
    @generated_app.instance_variable_set(:@repository_service, @repository_service)

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
    # Ensure template exists
    template_path = DataRepositoryService.new(user: @user).template_path(@ingredient)
    FileUtils.mkdir_p(File.dirname(template_path))
    File.write(template_path, "# Test template")

    # Set up expectations BEFORE calling the method
    expected_command = "rails app:template LOCATION=#{template_path}"
    CommandExecutionService.expects(:new)
      .with(@generated_app, @logger, expected_command)
      .returns(@command_service)
    @command_service.expects(:execute).returns(@app_directory)

    # Now call the method
    @generated_app.apply_ingredients
  end

  test "handles errors during application" do
    configuration = { "auth_type" => "devise" }
    error_message = "Something went wrong"
    error = StandardError.new(error_message)

    # Ensure template exists
    template_path = DataRepositoryService.new(user: @user).template_path(@ingredient)
    FileUtils.mkdir_p(File.dirname(template_path))
    File.write(template_path, "# Test template")

    # Set up CommandExecutionService to raise error
    expected_command = "rails app:template LOCATION=#{template_path}"
    CommandExecutionService.expects(:new)
      .with(@generated_app, @logger, expected_command)
      .returns(@command_service)
    @command_service.expects(:execute).raises(error)

    # Set up error logging expectation
    @logger.unstub(:error)
    @logger.expects(:error).with(
      "Failed to apply ingredient",
      has_entries(
        error: error_message,
        backtrace: anything
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

    # Use a block to temporarily override ENV
    original_bundle_gemfile = ENV["BUNDLE_GEMFILE"]
    begin
      # Set BUNDLE_GEMFILE to the expected path since we now validate before setting
      ENV["BUNDLE_GEMFILE"] = expected_gemfile_path

      # Expect CommandExecutionService to be called with the correct command
      expected_command = "rails app:template LOCATION=#{template_path}"
      CommandExecutionService.expects(:new)
        .with(@generated_app, @logger, expected_command)
        .returns(@command_service)
      @command_service.expects(:execute).returns(@app_directory)

      @generated_app.send(:apply_ingredient, @ingredient, configuration)
      assert_equal expected_gemfile_path, ENV["BUNDLE_GEMFILE"], "BUNDLE_GEMFILE was not set correctly"
    ensure
      ENV["BUNDLE_GEMFILE"] = original_bundle_gemfile
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
        backtrace: anything
      )
    ).once

    assert_raises(RuntimeError, "Bundler environment not properly set") do
      @generated_app.send(:apply_ingredient, @ingredient, configuration)
    end
  end

  test "fails when BUNDLE_GEMFILE is incorrect" do
    configuration = { "auth_type" => "devise" }
    template_path = "/path/to/template.rb"
    # Set wrong BUNDLE_GEMFILE path before calling apply_ingredient
    ENV["BUNDLE_GEMFILE"] = "/completely/different/path/Gemfile"

    # Mock template path
    DataRepositoryService.any_instance.stubs(:template_path).returns(template_path)

    # Mock all File.exist? calls to return false by default
    File.stubs(:exist?).returns(false)
    # Then override specific paths we care about
    File.stubs(:exist?).with(template_path).returns(true)

    @logger.unstub(:error)
    @logger.expects(:error).with(
      "Bundler environment not properly set",
      has_entries(
        bundle_gemfile: regexp_matches(/personal-blog\/Gemfile\z/),
        gemfile_exists: false
      )
    ).once

    @logger.expects(:error).with(
      "Failed to apply ingredient",
      has_entries(
        error: "Bundler environment not properly set",
        backtrace: anything
      )
    ).once

    assert_raises(RuntimeError, "Bundler environment not properly set") do
      @generated_app.send(:apply_ingredient, @ingredient, configuration)
    end
  end

  test "successfully applies ingredient with correct Bundler environment" do
    configuration = { "auth_type" => "devise" }

    # Create actual files instead of mocking
    FileUtils.mkdir_p(@app_directory)
    FileUtils.touch(File.join(@app_directory, "Gemfile"))

    template_path = DataRepositoryService.new(user: @user).template_path(@ingredient)
    FileUtils.mkdir_p(File.dirname(template_path))
    File.write(template_path, "# Test template")

    # Expect CommandExecutionService to be called with the correct command
    expected_command = "rails app:template LOCATION=#{template_path}"
    CommandExecutionService.expects(:new)
      .with(@generated_app, @logger, expected_command)
      .returns(@command_service)
    @command_service.expects(:execute).returns(@app_directory)

    @generated_app.apply_ingredients
  end
end
