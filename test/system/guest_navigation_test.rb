require "application_system_test_case"

class GuestNavigationsTest < ApplicationSystemTestCase
  # test "navigation links lead to correct pages for guest (not logged in) users" do
  #   visit root_path

  #   within "nav" do
  #     assert_link_visible "main-nav-link-home"
  #     assert_link_visible "main-nav-link-why"
  #     assert_link_visible "main-nav-link-live-demo"
  #     assert_link_visible "main-nav-link-about"
  #   end

  #   click_link_and_assert_navigation "main-nav-link-why", expected_path: why_path
  #   click_link_and_assert_navigation "main-nav-link-home", expected_path: root_path
  #   click_link_and_assert_navigation "main-nav-link-live-demo", expected_path: live_demo_path
  #   click_link_and_assert_navigation "main-nav-link-about", expected_path: about_path
  # end

  # private

  # def assert_link_visible(data_test_id)
  #   assert_selector "a[data-test-id='#{data_test_id}']"
  # end

  # def click_link_and_assert_navigation(data_test_id, expected_path:)
  #   find("a[data-test-id='#{data_test_id}']").click
  #   assert_current_path expected_path
  # end
end
