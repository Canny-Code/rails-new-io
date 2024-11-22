require "test_helper"

class SessionControllerTest < ActionDispatch::IntegrationTest
  setup do
    # without this omniauth.origin can be set to the one in previous test (tags_url) resulting in flaky tests
    OmniAuth.config.before_callback_phase do |env|
      env["omniauth.origin"] = nil
    end
  end

  test "guest should not be able to access dashboard" do
    get dashboard_path
    assert_redirected_to root_path

    get dashboard_url
    assert_response :redirect
    assert_redirected_to root_path
    assert_equal "Please sign in first.", flash[:alert]
  end

  test "authenticated github user should get dashboard" do
    login_with_github

    get dashboard_url
    assert_response :success

    delete sign_out_path
    assert_response :redirect
    assert_redirected_to root_url
    assert_equal "Signed out", flash[:notice]
  end


  test "successful github sign in" do
    login_with_github

    assert_response :redirect
    assert_redirected_to dashboard_url
    email = OmniAuth.config.mock_auth[:github][:info][:email]
    name = OmniAuth.config.mock_auth[:github][:info][:name]
    assert_equal "Logged in as #{name}", flash[:notice]
    assert User.pluck(:email).include?(email)
    assert_equal controller.current_user.email, email
  end

  test "github oauth failure" do
    silence_omniauth_logger do
      OmniAuth.config.test_mode = true
      OmniAuth.config.mock_auth[:github] = :invalid_credentials
      Rails.application.env_config["omniauth.auth"] = OmniAuth.config.mock_auth[:github]
      get "/auth/github/callback"
      follow_redirect!

      assert_response :redirect
      assert_redirected_to root_path
      assert_equal "Authentication failed", flash[:alert]
      assert_nil controller.current_user
    end
  end

  test "github auth with no email" do
    silence_omniauth_logger do
      auth_hash = OmniAuth::AuthHash.new({
        provider: "github",
        uid: "123456",
        info: {
          nickname: "test nickname",
          name: "Test User",
          email: nil,
          image: "https://avatars.githubusercontent.com/u/123545?v=3"
        }
      })

      OmniAuth.config.mock_auth[:github] = auth_hash

      # Start with the initial auth request
      post "/auth/github"
      assert_response :redirect
      # Now follow through to the callback
      follow_redirect!

      assert_redirected_to dashboard_url
      assert_not_nil session[:user_id]
    end
  end

  test "redirect to previous page after login" do
    user = users(:john)


    OmniAuth.config.before_callback_phase do |env|
      env["omniauth.origin"] = user_path(user)
    end

    sign_in(user)
    assert_response :redirect
    assert_redirected_to user_path(user)
  end

  test "github auth fails when user cannot be persisted" do
    silence_omniauth_logger do
      auth_hash = OmniAuth::AuthHash.new({
        provider: "github",
        uid: "", # Invalid uid (blank) will cause persistence to fail
        info: {
          nickname: "test nickname",
          name: "foo",
          email: "test@example.com",
          image: "https://avatars.githubusercontent.com/u/123545?v=3"
        }
      })

      OmniAuth.config.mock_auth[:github] = auth_hash
      Rails.application.env_config["omniauth.auth"] = auth_hash

      get "/auth/github/callback"

      assert_redirected_to root_url
      assert_equal "Failure", flash[:alert]
      assert_nil session[:user_id]
    end
  end
end