require "test_helper"

class RecipesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:jane)
    @other_user = users(:john)
    @recipe = recipes(:basic_recipe)
    @other_users_recipe = recipes(:minimal_recipe)
    sign_in @user

    # Mock Git operations
    GitRepo.any_instance.stubs(:commit_changes).returns(true)
    GitRepo.any_instance.stubs(:push_changes).returns(true)
    GitRepo.any_instance.stubs(:create_branch).returns(true)
    GitRepo.any_instance.stubs(:switch_branch).returns(true)
    GitRepo.any_instance.stubs(:sync_to_git).returns(true)
    Recipe.any_instance.stubs(:sync_to_git).returns(true)
    Recipe.any_instance.stubs(:head_commit_sha).returns("abc123")
  end

  test "index shows only current user's published recipes" do
    get recipes_path
    assert_response :success
    assert_includes @response.body, @recipe.name
    assert_not_includes @response.body, @other_users_recipe.name
  end

  test "index orders recipes by created_at desc" do
    newer_recipe = Recipe.create!(
      name: "Newer Recipe",
      cli_flags: "--api",
      status: "published",
      created_by: @user,
      head_commit_sha: "abc123" # Add required fields for GitBackedModel
    )

    get recipes_path
    assert_response :success
    assert_match(/#{newer_recipe.name}.*#{@recipe.name}/m, @response.body)
  end

  test "index requires authentication" do
    sign_out @user
    get recipes_path
    assert_redirected_to root_path
  end

  test "show displays recipe details" do
    get recipe_path(@recipe)
    assert_response :success
    assert_includes @response.body, @recipe.name
  end

  test "show requires authentication" do
    sign_out @user
    get recipe_path(@recipe)
    assert_redirected_to root_path
  end

  test "show prevents accessing other user's recipes" do
    get recipe_path(@other_users_recipe)
    assert_response :not_found
  end

  test "create makes new recipe with all parameters" do
    assert_difference("Recipe.count") do
      post recipes_path, params: {
        recipe: {
          name: "My API App",
          description: "A cool API app",
          status: "draft",
          api_flag: "--api",
          database_choice: "--database=postgresql",
          rails_flags: "--skip-test"
        }
      }
    end

    recipe = Recipe.last
    assert_equal "--api --database=postgresql --skip-test", recipe.cli_flags
    assert_equal "My API App", recipe.name
    assert_equal "A cool API app", recipe.description
    assert_equal "draft", recipe.status
    assert_redirected_to recipe_path(recipe)
    assert_equal "Recipe was successfully created.", flash[:notice]
  end

  test "create uses published as default status" do
    assert_difference("Recipe.count") do
      post recipes_path, params: {
        recipe: {
          name: "My API App",
          description: "A cool API app",
          api_flag: "--api"
        }
      }
    end

    assert_equal "published", Recipe.last.status
  end

  test "create prevents duplicate recipes with same CLI flags" do
    existing_recipe = recipes(:basic_recipe)

    assert_no_difference("Recipe.count") do
      post recipes_path, params: {
        recipe: {
          name: "Different Name",
          description: "Different description",
          status: "draft",
          api_flag: "--api",
          database_choice: "--database=mysql",
          rails_flags: nil
        }
      }
    end

    assert_redirected_to recipe_path(existing_recipe)
    assert_equal "A recipe with these settings already exists", flash[:alert]
  end

  test "create handles missing CLI flags gracefully" do
    assert_difference("Recipe.count") do
      post recipes_path, params: {
        recipe: {
          name: "Basic App",
          description: "A basic Rails app",
          status: "published",
          api_flag: nil,
          database_choice: nil,
          rails_flags: nil
        }
      }
    end

    recipe = Recipe.last
    assert_equal "", recipe.cli_flags
    assert_equal "Basic App", recipe.name
    assert_equal "A basic Rails app", recipe.description
    assert_equal "published", recipe.status
    assert_redirected_to recipe_path(recipe)
  end

  test "create with missing name renders new" do
    assert_no_difference("Recipe.count") do
      post recipes_path, params: {
        recipe: {
          description: "A description",
          api_flag: "--api"
        }
      }
    end

    assert_response :unprocessable_entity
  end

  test "create with invalid status fails validation" do
    assert_no_difference("Recipe.count") do
      post recipes_path, params: {
        recipe: {
          name: "My App",
          description: "A description",
          status: "invalid_status",
          api_flag: "--api"
        }
      }
    end

    assert_response :unprocessable_entity
  end

  test "create with invalid params renders new" do
    assert_no_difference("Recipe.count") do
      post recipes_path, params: {
        recipe: {
          name: "", # name is required
          api_flag: "--api"
        }
      }
    end

    assert_response :unprocessable_entity
  end

  test "create requires authentication" do
    sign_out @user
    post recipes_path
    assert_redirected_to root_path
  end

  test "destroy deletes the recipe" do
    assert_difference("Recipe.count", -1) do
      delete recipe_path(@recipe)
    end

    assert_redirected_to recipes_path
    assert_equal "Recipe was successfully deleted.", flash[:notice]
  end

  test "destroy requires authentication" do
    sign_out @user
    delete recipe_path(@recipe)
    assert_redirected_to root_path
  end

  test "destroy prevents deleting other user's recipes" do
    delete recipe_path(@other_users_recipe)
    assert_response :not_found
  end

  test "create with custom ingredients adds them to recipe" do
    ingredient = ingredients(:rails_authentication)

    assert_difference("Recipe.count") do
      assert_difference("RecipeIngredient.count") do
        post recipes_path, params: {
          recipe: {
            name: "Auth Recipe",
            description: "Recipe with authentication",
            api_flag: "--api",
            ingredient_ids: [ ingredient.id ]
          }
        }
      end
    end

    recipe = Recipe.last
    assert_equal "Auth Recipe", recipe.name
    assert_includes recipe.ingredients, ingredient
    assert_redirected_to recipe_path(recipe)
  end

  test "create with multiple custom ingredients adds all of them" do
    auth = ingredients(:rails_authentication)
    basic = ingredients(:basic)

    assert_difference("Recipe.count") do
      assert_difference("RecipeIngredient.count", 2) do
        post recipes_path, params: {
          recipe: {
            name: "Multi-ingredient Recipe",
            description: "Recipe with multiple ingredients",
            api_flag: "--api",
            ingredient_ids: [ auth.id, basic.id ]
          }
        }
      end
    end

    recipe = Recipe.last
    assert_equal "Multi-ingredient Recipe", recipe.name
    assert_includes recipe.ingredients, auth
    assert_includes recipe.ingredients, basic
    assert_redirected_to recipe_path(recipe)
  end

  test "create with non-existent custom ingredients ignores them" do
    auth = ingredients(:rails_authentication)

    assert_difference("Recipe.count") do
      assert_difference("RecipeIngredient.count", 1) do
        post recipes_path, params: {
          recipe: {
            name: "Mixed Recipe",
            description: "Recipe with mix of real and fake ingredients",
            api_flag: "--api",
            ingredient_ids: [ auth.id, 999999 ]
          }
        }
      end
    end

    recipe = Recipe.last
    assert_equal "Mixed Recipe", recipe.name
    assert_includes recipe.ingredients, auth
    assert_equal 1, recipe.ingredients.count
    assert_redirected_to recipe_path(recipe)
  end
end
