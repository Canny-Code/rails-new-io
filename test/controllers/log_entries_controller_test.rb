require "test_helper"

class LogEntriesControllerTest < ActionDispatch::IntegrationTest
  def setup
    @user = users(:john)
    @generated_app = generated_apps(:saas_starter)
    @generated_app.update!(user: @user)
    sign_in @user
  end

  test "should get index" do
    get generated_app_log_entries_path(@generated_app)
    assert_response :success
  end

  test "should order log entries by created_at desc" do
    # Create log entries with different timestamps and distinct messages
    messages = [ "First log", "Second log", "Third log" ]
    messages.each_with_index do |msg, i|
      @generated_app.log_entries.create!(
        level: :info,
        message: msg,
        phase: :pending,
        created_at: i.hours.ago
      )
    end

    get generated_app_log_entries_path(@generated_app)
    assert_response :success

    # Check that messages appear in reverse chronological order
    response_body = response.body
    last_index = Float::INFINITY
    messages.reverse.each do |msg|
      current_index = response_body.index(msg)
      assert current_index, "Message '#{msg}' not found in response"
      if last_index != Float::INFINITY
        assert current_index < last_index, "Message '#{msg}' appears out of order"
      end
      last_index = current_index
    end
  end

  test "should require authentication" do
    sign_out @user
    get generated_app_log_entries_path(@generated_app)
    assert_redirected_to root_path
    assert_equal "Please sign in first.", flash[:alert]
  end

  test "should show github clone box when app is completed" do
    @generated_app.app_status.update!(status: :pushing_to_github)
    get generated_app_log_entries_path(@generated_app)
    assert_response :success
    assert_select "#github_clone_box", text: /git clone/, count: 0

    @generated_app.app_status.start_ci!
    Current.user = @user # Ensure Current.user is set before completing
    @generated_app.app_status.complete!

    get generated_app_log_entries_path(@generated_app)
    assert_response :success
    assert_select "#github_clone_box", /git clone git@github.com:johndoe\/saas-starter.git/
  end
end
