require "test_helper"

class UsersControllerTest < ActionDispatch::IntegrationTest
  test "should redierect for unauthenticated user" do
    user = users(:john)
    get user_path(user)

    assert_response :redirect
    assert_redirected_to root_path
    assert_equal "Please sign in first.", flash[:alert]
  end

  test "should get show for authenticated user" do
    user = users(:john)
    sign_in(user)
    get user_path(user)

    assert_response :success
  end

  test "should raise error for non-existent user" do
    user = users(:john)
    sign_in(user)
    get user_path("non-existent-user")

    assert_response :redirect
    assert_redirected_to root_path
    assert_equal "User not found", flash[:alert]
  end
end
