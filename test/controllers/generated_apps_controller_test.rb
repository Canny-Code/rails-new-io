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

  test "requires authentication" do
    sign_out(@user)
    post generated_apps_path, params: { app_name: "test-app" }
    assert_redirected_to root_path
    assert_equal "Please sign in first.", flash[:alert]
  end

  test "creates app with valid parameters" do
    app_name = "my-test-app"
    api_flag = "--api"
    database = "--database=mysql"

    Recipe.any_instance.stubs(:commit_changes).returns(true)
    Recipe.any_instance.stubs(:initial_git_commit).returns(true)
    GeneratedApp.any_instance.stubs(:commit_changes).returns(true)
    GeneratedApp.any_instance.stubs(:initial_git_commit).returns(true)

    assert_difference "GeneratedApp.count" do
      assert_difference "Recipe.count" do
        post generated_apps_path, params: {
          app_name: app_name,
          api_flag: api_flag,
          database_choice: database
        }
      end
    end

    app = GeneratedApp.last
    assert_equal app_name, app.name
    assert_equal @user, app.user
    assert_equal "#{api_flag} #{database}", app.recipe.cli_flags

    assert_redirected_to generated_app_log_entries_path(app)
  end

  test "reuses existing recipe if cli flags match" do
    recipe = recipes(:api_recipe) # Has "--api --database=postgresql" flags

    GeneratedApp.any_instance.stubs(:commit_changes).returns(true)
    GeneratedApp.any_instance.stubs(:initial_git_commit).returns(true)

    assert_difference "GeneratedApp.count" do
      assert_no_difference "Recipe.count" do
        post generated_apps_path, params: {
          app_name: "new-api",
          api_flag: "--api",
          database_choice: "--database=postgresql"
        }
      end
    end

    app = GeneratedApp.last
    assert_equal recipe, app.recipe
  end

  test "starts app generation after creation" do
    Recipe.any_instance.stubs(:commit_changes).returns(true)
    Recipe.any_instance.stubs(:initial_git_commit).returns(true)
    GeneratedApp.any_instance.stubs(:commit_changes).returns(true)
    GeneratedApp.any_instance.stubs(:initial_git_commit).returns(true)

    AppGeneration::Orchestrator.any_instance.expects(:call)

    post generated_apps_path, params: {
      app_name: "test-app",
      api_flag: "--api",
      database_choice: "--database=mysql"
    }
  end
end
