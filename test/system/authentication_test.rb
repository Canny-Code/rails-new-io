require "application_system_test_case"

class AuthenticationTest < ApplicationSystemTestCase
  test "user can sign in and sign out with GitHub" do
    # Setup OmniAuth mock for GitHub
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:github] = OmniAuth::AuthHash.new({
      provider: "github",
      uid: "123456",
      info: {
        email: "test@example.com",
        name: "Test User",
        image: "http://example.com/image.jpg"
      },
      credentials: {
        token: "mock_token"
      },
      extra: {
        raw_info: {
          login: "testuser"
        }
      }
    })

    # Visit the home page
    visit root_path

    # Click sign in
    click_on "Get in"

    # Verify we're signed in
    assert_text "Logout"

    # Sign out
    click_on "Logout"

    # Verify we're signed out
    assert_text "Get in"
  end

  teardown do
    OmniAuth.config.mock_auth[:github] = nil
  end
end
