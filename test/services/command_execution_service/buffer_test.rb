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
