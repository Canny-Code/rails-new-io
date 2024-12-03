require "test_helper"

class AuthenticationFlowTest < ActionDispatch::IntegrationTest
  test "login/logout flow shows correct buttons" do
    # Start as guest
    get root_path
    assert_select "button", text: "Get in"
    assert_select "button", text: "Logout", count: 0

    # Login
    sign_in users(:john)
    get dashboard_path
    assert_select "button", text: "Logout"
    assert_select "button", text: "Get in", count: 0

    # Logout
    delete sign_out_path
    follow_redirect!
    assert_select "button", text: "Get in"
    assert_select "button", text: "Logout", count: 0
  end
end
