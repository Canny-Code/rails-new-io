require "test_helper"

class CommandExecutionService
  class BufferTest < ActiveSupport::TestCase
    def setup
      @user = users(:john)
      @recipe = recipes(:blog_recipe)

      # Stub GitRepo to avoid GitHub API calls
      @git_repo = mock("GitRepo")
      @git_repo.stubs(:commit_changes)
      GitRepo.stubs(:new).returns(@git_repo)

      @generated_app = GeneratedApp.create!(
        name: "test-app",
        user: @user,
        recipe: @recipe,
        ruby_version: "3.2.0",
        rails_version: "7.1.0",
        selected_gems: [],
        configuration_options: {}
      )
      @buffer = Buffer.new(@generated_app)
    end

    test "updates log entry message without changing entry_type when not completed" do
      @buffer.append("First message")
      @buffer.append("Second message")

      # Force a flush without completing
      @buffer.flush

      log_entry = AppGeneration::LogEntry.last
      assert_equal "First message\nSecond message", log_entry.message
      assert_equal "rails_output", log_entry.entry_type
    end
  end
end
