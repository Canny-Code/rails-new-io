require "test_helper"
require_relative "../support/git_test_helper"

class GeneratedAppsControllerTest < ActionDispatch::IntegrationTest
  include GitTestHelper

  setup do
    @user = users(:jane)
    sign_in(@user)
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
    app_name = "my-test-app"
    recipe = recipes(:basic_recipe)

    GeneratedApp.any_instance.stubs(:commit_changes).returns(true)
    GeneratedApp.any_instance.stubs(:initial_git_commit).returns(true)

    assert_difference "GeneratedApp.count" do
      post generated_apps_path, params: {
        generated_app: {
          recipe_id: recipe.id
        },
        app_name: app_name
      }
    end

    app = GeneratedApp.last
    assert_equal app_name, app.name
    assert_equal @user, app.user
    assert_equal recipe, app.recipe

    assert_redirected_to generated_app_log_entries_path(app)
  end

  test "reuses existing recipe if cli flags match" do
    recipe = recipes(:api_recipe) # Has "--api --database=postgresql" flags

    GeneratedApp.any_instance.stubs(:commit_changes).returns(true)
    GeneratedApp.any_instance.stubs(:initial_git_commit).returns(true)

    assert_difference "GeneratedApp.count" do
      assert_no_difference "Recipe.count" do
        post generated_apps_path, params: {
          generated_app: {
            recipe_id: recipe.id
          },
          app_name: "new-api"
        }
      end
    end

    app = GeneratedApp.last
    assert_equal recipe, app.recipe
  end

  test "starts app generation after creation" do
    recipe = recipes(:basic_recipe)

    GeneratedApp.any_instance.stubs(:commit_changes).returns(true)
    GeneratedApp.any_instance.stubs(:initial_git_commit).returns(true)

    AppGeneration::Orchestrator.any_instance.expects(:call)

    post generated_apps_path, params: {
      generated_app: {
        recipe_id: recipe.id
      },
      app_name: "test-app"
    }
  end
end
