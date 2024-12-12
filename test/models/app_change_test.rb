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

    # Mock the system call
    pid = 12345
    Process.expects(:spawn).with(
      { "DISABLE_SPRING" => "true" },
      "bin/rails app:template LOCATION=#{template_path}",
      chdir: @generated_app.source_path
    ).returns(pid)

    status = mock("status")
    status.stubs(:success?).returns(true)
    Process.expects(:wait2).with(pid).returns([ nil, status ])

    # Execute and verify
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
    FileUtils.stubs(:mkdir_p)  # Change to stubs
    File.expects(:write).with(template_path, "# Bad template")
    FileUtils.expects(:rm_f).with(template_path)  # Expect cleanup

    # Mock the system call to fail
    Process.expects(:spawn).with(
      { "DISABLE_SPRING" => "true" },
      "bin/rails app:template LOCATION=#{template_path}",
      chdir: @generated_app.source_path
    ).returns(123)

    status = mock("status")
    status.stubs(:success?).returns(false)
    Process.expects(:wait2).returns([ nil, status ])

    # Execute and verify
    @app_change.apply!

    assert_not @app_change.success?
    assert_not_nil @app_change.applied_at
    assert_not_nil @app_change.error_message
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

    # Mock the system call
    Process.expects(:spawn).with(
      { "DISABLE_SPRING" => "true" },
      "bin/rails app:template LOCATION=#{template_path}",
      chdir: @generated_app.source_path
    ).returns(123)

    status = mock("status")
    status.stubs(:success?).returns(true)
    Process.expects(:wait2).returns([ nil, status ])

    @app_change.apply!
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
end
