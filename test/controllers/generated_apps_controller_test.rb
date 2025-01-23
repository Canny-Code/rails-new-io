require "test_helper"
require_relative "../support/git_test_helper"

class GeneratedAppsControllerTest < ActionDispatch::IntegrationTest
  include GitTestHelper

  setup do
    @user = users(:john)
    @recipe = recipes(:blog)
    sign_in @user
  end

  test "should show generated app" do
    get generated_app_url(generated_apps(:blog_app))
    assert_response :success
  end

  test "new shows only current user's published recipes" do
    get new_generated_app_path
    assert_response :success

    response_body = response.body

    # Should include current user's published recipes
    assert_match recipes(:api_recipe).name, response_body
    assert_match recipes(:basic_recipe).name, response_body

    # Should not include draft recipes
    assert_no_match recipes(:blog_recipe).name, response_body
    # Should not include other user's recipes
    assert_no_match recipes(:minimal_recipe).name, response_body
  end

  test "requires authentication" do
    sign_out(@user)
    post generated_apps_path, params: { app_name: "test-app" }
    assert_redirected_to root_path
    assert_equal "Please sign in first.", flash[:alert]
  end

  test "creates app with valid parameters" do
    assert_difference("GeneratedApp.count") do
      post generated_apps_path, params: {
        generated_app: {
          name: "test-app",
          recipe_id: @recipe.id,
          ruby_version: "3.2.2",
          rails_version: "7.1.2",
          selected_gems: [],
          configuration_options: {}
        }
      }
    end

    assert_redirected_to generated_app_path(GeneratedApp.last)
  end

  test "reuses existing recipe if cli_flags match" do
    assert_difference("GeneratedApp.count") do
      post generated_apps_path, params: {
        generated_app: {
          name: "test-app",
          recipe_id: @recipe.id,
          ruby_version: "3.2.2",
          rails_version: "7.1.2",
          selected_gems: [],
          configuration_options: {}
        }
      }
    end

    assert_redirected_to generated_app_path(GeneratedApp.last)
  end

  test "starts app generation after creation" do
    AppGeneration::Orchestrator.any_instance.expects(:call).once

    post generated_apps_path, params: {
      generated_app: {
        name: "test-app",
        recipe_id: @recipe.id,
        ruby_version: "3.2.2",
        rails_version: "7.1.2",
        selected_gems: [],
        configuration_options: {}
      }
    }
  end
end
