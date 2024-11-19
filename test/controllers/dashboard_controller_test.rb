require "test_helper"

class DashboardControllerTest < ActionDispatch::IntegrationTest
  test "should get show" do
    user = users(:john)
    sign_in(user)
    get dashboard_path
    assert_response :success
  end
end
