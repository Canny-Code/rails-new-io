require "test_helper"

class StaticControllerTest < ActionDispatch::IntegrationTest
  test "should get Home" do
    get home_url
    assert_response :success
    assert_select "title", "Home | railsnew.io"
  end

  test "should get About" do
    get about_url
    assert_response :success
    assert_select "title", "About | railsnew.io"
  end

  test "should get why" do
    get why_url
    assert_response :success
    assert_select "title", "Why | railsnew.io"
  end

  test "should get Live Demo" do
    get live_demo_url
    assert_response :success
    assert_select "title", "Live Demo | railsnew.io"
  end


end
