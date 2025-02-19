require "test_helper"

class CommandExecutionService::BufferTest < ActiveSupport::TestCase
  def setup
    @user = users(:john)
    @recipe = recipes(:blog_recipe)
    @app = GeneratedApp.create!(
      user: @user,
      recipe: @recipe,
      name: "test-app",
      selected_gems: [],
      configuration_options: {}
    )
    @command = "rails new #{@app.name} -d postgres"
    @buffer = CommandExecutionService::Buffer.new(@app, @command)
    @initial_log_count = @app.log_entries.count
  end

  test "creates new log entry during flush if @log_entry is nil" do
    @buffer.instance_variable_set(:@log_entry, nil) # Force creation of new entry
    @buffer.append("test output")
    @buffer.flush

    assert_equal @initial_log_count + 1, @app.log_entries.count
    assert_equal "Command execution started: `#{@command}`\ntest output", @app.log_entries.last.message
    assert_equal "rails_output", @app.log_entries.last.entry_type
  end

  test "updates log entry message without changing entry_type when not completed" do
    @buffer.append("first line")
    @buffer.flush
    @buffer.append("second line")
    @buffer.flush

    assert_equal @initial_log_count, @app.log_entries.count
    assert_equal "Command execution started: `#{@command}`\nfirst line\nsecond line", @app.log_entries.last.message
    assert_equal "rails_output", @app.log_entries.last.entry_type
  end
end
