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
    sign_in(users(:john))

    get dashboard_url
    assert_response :success

    delete sign_out_path
    assert_response :redirect
    assert_redirected_to root_url
    assert_equal "Signed out", flash[:notice]
  end


  test "successful github sign_in" do
    user = users(:john)
    auth_hash = OmniAuth::AuthHash.new({
      provider: "github",
      uid: user.uid,
      info: {
        name: user.name,
        email: user.email,
        nickname: user.github_username,
        image: user.image
      },
      credentials: {
        token: "mock_token"
      },
      extra: {
        raw_info: {
          login: user.github_username
        }
      }
    })

    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:github] = auth_hash

    assert_enqueued_with(job: InitializeUserDataRepositoryJob, args: [ user.id ]) do
      get "/auth/github/callback", env: { 'omniauth.auth': auth_hash }
    end

    assert_response :redirect
    assert_redirected_to dashboard_url
    assert_equal user.id, session[:user_id]
    assert_equal "Logged in as #{user.name}", flash[:notice]
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
    OmniAuth.config.test_mode = true
    auth_hash = OmniAuth::AuthHash.new({
      provider: "github",
      uid: "1238383456",
      info: {
        name: "Test User",
        email: nil,
        image: "https://avatars.githubusercontent.com/u/123545?v=3"
      },
      extra: {
        raw_info: {
          login: "test"
        }
      },
      credentials: {
        token: "very-secret-token"
      }
    })

    OmniAuth.config.mock_auth[:github] = auth_hash

    post "/auth/github"
    follow_redirect!

    assert_redirected_to dashboard_url
    assert_not_nil session[:user_id]
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
    # Clean up in correct order to respect foreign key constraints
    AppGeneration::LogEntry.delete_all
    AppStatus.delete_all
    Commit.delete_all
    GeneratedApp.delete_all
    RecipeIngredient.delete_all
    Recipe.delete_all
    Element::CustomIngredientCheckbox.delete_all
    Ingredient.delete_all
    Noticed::Notification.delete_all
    Element.delete_all
    User.delete_all

    silence_omniauth_logger do
      OmniAuth.config.test_mode = true
      auth_hash = OmniAuth::AuthHash.new({
        provider: "github",
        uid: "12382900456",
        info: {
          name: "foo",
          email: "test@example.com",
          image: "https://avatars.githubusercontent.com/u/123545?v=3"
        },
        extra: {
          raw_info: {
            login: nil
          }
        },
        credentials: {
          token: "very-secret-token"
        }
      })

      OmniAuth.config.mock_auth[:github] = auth_hash
      OmniAuth.config.on_failure = Proc.new { |env|
        OmniAuth::FailureEndpoint.new(env).redirect_to_failure
      }

      post "/auth/github"
      follow_redirect!

      assert_redirected_to root_path
      assert_equal "Failure", flash[:alert]
      assert_nil session[:user_id]
    end
  end
end
