require "test_helper"

class CommandExecutionService::BufferTest < ActiveSupport::TestCase
  def setup
    @user = users(:john)
    @recipe = recipes(:blog)
    @app = GeneratedApp.create!(
      user: @user,
      recipe: @recipe,
      name: "test-app",
      ruby_version: "3.2.2",
      rails_version: "7.1.2",
      selected_gems: [],
      configuration_options: {}
    )
    @buffer = CommandExecutionService::Buffer.new(@app)
  end

  test "creates new log entry during flush if @log_entry is nil" do
    @buffer.append("test output")
    @buffer.flush

    assert_equal 1, @app.log_entries.count
    assert_equal "test output", @app.log_entries.first.message
    assert_equal "info", @app.log_entries.first.entry_type
  end

  test "updates log entry message without changing entry_type when not completed" do
    @buffer.append("first line")
    @buffer.flush
    @buffer.append("second line")
    @buffer.flush

    assert_equal 1, @app.log_entries.count
    assert_equal "first line\nsecond line", @app.log_entries.first.message
    assert_equal "info", @app.log_entries.first.entry_type
  end
end
