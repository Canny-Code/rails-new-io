require "test_helper"

class GeneratedAppsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:jane)
    @generated_app = generated_apps(:blog_app)
    sign_in @user
  end

  test "should show generated app" do
    get generated_app_url(@generated_app)
    assert_response :success

    assert_select "h1", @generated_app.name
    assert_select "p", @generated_app.description
    assert_select "p", @generated_app.ruby_version
    assert_select "p", @generated_app.rails_version
    assert_select "a[href=?]", @generated_app.github_repo_url
  end

  test "should not show generated app for unauthorized user" do
    sign_out @user
    get generated_app_url(@generated_app)
    assert_redirected_to root_url
  end
end
