require "test_helper"

class OnboardingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:john)
  end

  test "should update onboarding status and redirect to dashboard" do
    sign_in @user
    patch onboarding_path

    assert_redirected_to dashboard_path
    assert_equal "Welcome to railsnew.io!", flash[:notice]
    assert @user.reload.onboarding_completed?
  end

  test "should require authentication" do
    patch onboarding_path
    assert_redirected_to new_user_session_path
  end
end
