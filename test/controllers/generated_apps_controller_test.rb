require "test_helper"
require_relative "../support/git_test_helper"

class GeneratedAppsControllerTest < ActionDispatch::IntegrationTest
  include GitTestHelper

  setup do
    @user = users(:john)
    @recipe = recipes(:api_recipe)
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
    assert_match recipes(:minimal_recipe).name, response_body  # John's published recipe
    assert_match recipes(:blog_recipe).name, response_body    # John's published recipe

    # Should not include other user's recipes
    assert_no_match recipes(:api_recipe).name, response_body    # Jane's recipe
    assert_no_match recipes(:basic_recipe).name, response_body  # Jane's recipe
  end

  test "requires authentication" do
    sign_out(@user)
    post generated_apps_path, params: { app_name: "test-app" }
    assert_redirected_to root_path
    assert_equal "Please sign in first.", flash[:alert]
  end

  test "creates app with valid parameters" do
    recipe = recipes(:minimal_recipe) # This recipe belongs to John
    assert_difference("GeneratedApp.count") do
      post generated_apps_path, params: {
        app_name: "test-app",
        generated_app: {
          recipe_id: recipe.id,
          selected_gems: [],
          configuration_options: {}
        }
      }
    end

    assert_redirected_to generated_app_log_entries_path(GeneratedApp.last)
  end

  test "reuses existing recipe if cli_flags match" do
    recipe = recipes(:minimal_recipe) # This recipe belongs to John
    assert_difference("GeneratedApp.count") do
      post generated_apps_path, params: {
        app_name: "test-app",
        generated_app: {
          recipe_id: recipe.id,
          selected_gems: [],
          configuration_options: {}
        }
      }
    end

    assert_redirected_to generated_app_log_entries_path(GeneratedApp.last)
  end

  test "starts app generation after creation" do
    recipe = recipes(:minimal_recipe) # This recipe belongs to John
    AppGenerationJob.expects(:perform_later).once

    post generated_apps_path, params: {
      app_name: "test-app",
      generated_app: {
        recipe_id: recipe.id,
        selected_gems: [],
        configuration_options: {}
      }
    }
  end

  test "create fails with validation error when app name is not unique for user" do
    @recipe.update!(created_by: @user)
    # First create an app with a specific name
    GeneratedApp.create!(
      name: "my-app",
      user: @user,
      recipe: @recipe,
      selected_gems: [],
      configuration_options: {}
    )

    assert_no_difference "GeneratedApp.count" do
      post generated_apps_path, params: {
        app_name: "my-app",
        generated_app: { recipe_id: @recipe.id }
      }
    end

    assert_redirected_to new_generated_app_path
    assert_equal "Failed to create generated app: Name has already been taken", flash[:alert]
  end

  test "create fails when recipe_id is nil" do
    assert_no_difference "GeneratedApp.count" do
      post generated_apps_path, params: {
        app_name: "my-app",
        generated_app: { recipe_id: nil }
      }
    end

    assert_redirected_to new_generated_app_path
    assert_equal "Recipe not found - you either don't have access to this recipe or it doesn't exist", flash[:alert]
  end
end
