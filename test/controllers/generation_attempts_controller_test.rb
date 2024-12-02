require "test_helper"

class GenerationAttemptsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:jane)
    @failed_app = generated_apps(:api_project)  # has failed_api_status
    sign_in @user
  end

  test "creates a new generation attempt for failed app" do
    assert_equal "failed", @failed_app.status

    post generated_app_generation_attempts_path(@failed_app)

    assert_equal "pending", @failed_app.reload.status
  end

  test "does not create generation attempt for non-failed app" do
    completed_app = generated_apps(:api_project_3)  # has completed_api_status
    assert_equal "completed", completed_app.status

    post generated_app_generation_attempts_path(completed_app)

    assert_equal "completed", completed_app.reload.status
  end

  test "requires authentication" do
    sign_out @user

    post generated_app_generation_attempts_path(@failed_app)

    assert_redirected_to root_path
  end

  test "responds to turbo stream format" do
    post generated_app_generation_attempts_path(@failed_app),
      as: :turbo_stream

    assert_response :success
    assert_equal "pending", @failed_app.reload.status
  end
end
