# == Schema Information
#
# Table name: app_changes
#
#  id               :integer          not null, primary key
#  applied_at       :datetime
#  configuration    :json
#  error_message    :text
#  success          :boolean
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  generated_app_id :integer          not null
#  recipe_change_id :integer
#
# Indexes
#
#  index_app_changes_on_generated_app_id  (generated_app_id)
#  index_app_changes_on_recipe_change_id  (recipe_change_id)
#
# Foreign Keys
#
#  generated_app_id  (generated_app_id => generated_apps.id) ON DELETE => cascade
#  recipe_change_id  (recipe_change_id => recipe_changes.id) ON DELETE => cascade
#
require "test_helper"
require "ostruct"

class AppChangeTest < ActiveSupport::TestCase
  setup do
    @app_change = app_changes(:blog_auth_change)
    @generated_app = @generated_app || generated_apps(:blog_app)
    @recipe_change = @app_change.recipe_change

    # Ensure source path exists
    @generated_app.source_path = Rails.root.join("tmp", "test_apps", "blog_app")
    @generated_app.save!
  end

  test "applies change successfully" do
    # Mock the configuration processing
    @app_change.configuration = { "auth_type" => "devise" }
    @recipe_change.expects(:apply_to_app).with(@generated_app, @app_change.configuration).returns("# Template content")

    # Mock the file operations
    template_path = Rails.root.join("tmp", "templates", @app_change.id.to_s)
    FileUtils.stubs(:mkdir_p)
    File.expects(:write).with(template_path, "# Template content")
    FileUtils.expects(:rm_f).with(template_path)

    # Mock CommandExecutionService
    mock_execution = mock
    mock_execution.expects(:execute)
    CommandExecutionService.expects(:new).
      with(@generated_app, "bin/rails app:template LOCATION=#{template_path}").
      returns(mock_execution)

    @app_change.apply!

    assert @app_change.success?
    assert_not_nil @app_change.applied_at
    assert_nil @app_change.error_message
  end

  test "handles failed application" do
    # Mock the configuration processing
    @app_change.configuration = { "auth_type" => "devise" }
    @recipe_change.expects(:apply_to_app).with(@generated_app, @app_change.configuration).returns("# Bad template")

    # Mock the file operations
    template_path = Rails.root.join("tmp", "templates", @app_change.id.to_s)
    FileUtils.stubs(:mkdir_p)
    File.expects(:write).with(template_path, "# Bad template")
    FileUtils.expects(:rm_f).with(template_path)

    # Mock CommandExecutionService with failure
    mock_execution = mock
    mock_execution.expects(:execute).raises(RuntimeError.new("Template application failed"))
    CommandExecutionService.expects(:new).
      with(@generated_app, "bin/rails app:template LOCATION=#{template_path}").
      returns(mock_execution)

    @app_change.apply!

    assert_not @app_change.success?
    assert_not_nil @app_change.applied_at
    assert_equal "Template application failed", @app_change.error_message
  end

  test "cleans up template file after application" do
    # Mock the configuration processing
    @app_change.configuration = { "auth_type" => "devise" }
    @recipe_change.expects(:apply_to_app).with(@generated_app, @app_change.configuration).returns("# Template content")

    # Mock the file operations
    template_path = Rails.root.join("tmp", "templates", @app_change.id.to_s)
    FileUtils.stubs(:mkdir_p)  # Change to stubs
    File.expects(:write).with(template_path, "# Template content")
    FileUtils.expects(:rm_f).with(template_path)  # Always expect cleanup

    # Mock CommandExecutionService
    mock_execution = mock
    mock_execution.expects(:execute)
    CommandExecutionService.expects(:new).
      with(@generated_app, "bin/rails app:template LOCATION=#{template_path}").
      returns(mock_execution)

    @app_change.apply!

    assert @app_change.success?
    assert_not_nil @app_change.applied_at
  end

  test "handles errors during application" do
    # Mock the configuration processing to raise an error
    @app_change.configuration = { "auth_type" => "devise" }
    error_message = "Failed to process template"

    freeze_time do
      @recipe_change.expects(:apply_to_app).
        with(@generated_app, @app_change.configuration).
        raises(StandardError.new(error_message))

      # Mock file operations since they're in ensure block
      template_path = Rails.root.join("tmp", "templates", @app_change.id.to_s)
      FileUtils.stubs(:mkdir_p)
      FileUtils.expects(:rm_f).with(template_path)

      # Execute and verify
      assert_raises(StandardError) do
        @app_change.apply!
      end

      # Verify the error was recorded
      @app_change.reload
      assert_not @app_change.success?
      assert_not_nil @app_change.applied_at
      assert_equal Time.current.to_i, @app_change.applied_at.to_i  # Compare timestamps as integers
      assert_equal error_message, @app_change.error_message
    end
  end

  test "skips application if already applied" do
    freeze_time do
      applied_time = 1.hour.ago
      @app_change.update!(applied_at: applied_time, success: true)

      # Verify that none of the application logic is called
      @recipe_change.expects(:apply_to_app).never
      FileUtils.expects(:mkdir_p).never
      File.expects(:write).never

      @app_change.apply!

      # Verify nothing changed
      @app_change.reload
      assert_equal applied_time.to_i, @app_change.applied_at.to_i
      assert @app_change.success?
    end
  end

  test "to_git_format includes recipe change type" do
    app_change = app_changes(:blog_auth_change)  # Use existing fixture

    git_format = app_change.to_git_format

    assert_equal app_change.recipe_change.change_type, git_format[:recipe_change_type]
    assert_equal app_change.configuration, git_format[:configuration]
    assert_nil git_format[:applied_at], "Expected applied_at to be nil for unapplied change"
    assert_equal false, git_format[:success], "Expected success to be false for unapplied change"
    assert_nil git_format[:error_message], "Expected error_message to be nil for unapplied change"
  end

  private

  def mock_popen3(stdout, stderr, success: true, pid: 12345)
    lambda do |env, command, **options, &block|
      mock_stdin = StringIO.new
      mock_stdout = StringIO.new(stdout)
      mock_stderr = StringIO.new(stderr)
      mock_wait_thread = OpenStruct.new(
        pid: pid,
        value: OpenStruct.new(success?: success)
      )

      block.call(mock_stdin, mock_stdout, mock_stderr, mock_wait_thread)
    end
  end
end
