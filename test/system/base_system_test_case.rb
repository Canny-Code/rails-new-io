require "application_system_test_case"

class BaseSystemTestCase < ApplicationSystemTestCase
  def setup
    super
    setup_omniauth
  end

  def teardown
    super
    cleanup_omniauth
  end

  private

  def setup_omniauth
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:github] = nil
  end

  def cleanup_omniauth
    OmniAuth.config.mock_auth[:github] = nil
  end

  def sign_in_as(user)
    OmniAuth.config.mock_auth[:github] = OmniAuth::AuthHash.new(
      provider: user.provider,
      uid: user.uid,
      info: {
        email: user.email,
        name: user.name,
        image: user.image,
        nickname: user.github_username
      },
      credentials: {
        token: "mock_token"
      },
      extra: {
        raw_info: {
          login: user.github_username
        }
      }
    )

    visit root_path
    click_on "Get in"
    assert_selector "button", text: "Logout", wait: 5
  end

  def sign_out
    click_on "Logout"
    assert_selector "button", text: "Get in", wait: 5
  end
end
