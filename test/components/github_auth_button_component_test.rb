# test/components/github_auth_button_component_test.rb
require "test_helper"
require "support/phlex_component_test_case"

class GithubAuthButton::ComponentTest < PhlexComponentTestCase
  test "renders login button when user is not logged in" do
    Current.stub(:user, nil) do
      component = GithubAuthButton::Component.new
      rendered = component.render_in(view_context)
      assert_includes rendered, "Get in"
      assert_includes rendered, "/auth/github"
    end
  end

  test "renders logout button when user is logged in" do
    user = User.create!(
      name: "Test User",
      provider: "github",
      uid: "123456",
      github_username: "testuser"
    )

    Current.stub(:user, user) do
      component = GithubAuthButton::Component.new
      rendered = component.render_in(view_context)
      assert_includes rendered, "Logout"
      assert_includes rendered, "/sign_out"
    end
  end

  private

  def view_context
    controller.view_context
  end

  def controller
    @controller ||= ApplicationController.new.tap do |c|
      c.request = ActionDispatch::TestRequest.create
      c.response = ActionDispatch::TestResponse.new
    end
  end
end
