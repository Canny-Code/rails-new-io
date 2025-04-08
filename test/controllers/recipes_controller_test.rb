require "test_helper"

class RecipesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @recipe = recipes(:blog_recipe)
    @user = users(:john)
    @other_users_recipe = recipes(:api_recipe)
    sign_in @user

    DataRepositoryService.any_instance.stubs(:push_app_files).returns(true)
    DataRepositoryService.any_instance.stubs(:initialize_repository).returns(true)
    DataRepositoryService.stubs(:name_for_environment).returns("rails-new-io-data-test")
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

  test "create makes new recipe with all parameters and enqueues WriteRecipeJob" do
    assert_difference("Recipe.count") do
      post recipes_path, params: {
        recipe: {
          name: "My API App",
          description: "A cool API app",
          status: "draft",
          api_flag: "--api",
          ui_state: "{}",
          database_choice: "--database=postgresql",
          rails_flags: "--skip-test"
        }
      }
    end

    new_recipe = @controller.instance_variable_get(:@recipe)
    assert new_recipe.persisted?
    assert_equal "--api --database=postgresql --skip-test", new_recipe.cli_flags
    assert_equal "My API App", new_recipe.name
    assert_equal "A cool API app", new_recipe.description
    assert_equal "draft", new_recipe.status

    assert_enqueued_with(
      job: WriteRecipeJob,
      args: [ {
        recipe_id: new_recipe.id,
        user_id: @user.id
      } ]
    )

    assert_redirected_to recipe_path(new_recipe)
    assert_equal "Recipe was successfully created.", flash[:notice]
  end

  test "create uses published as default status" do
    assert_difference("Recipe.count") do
      post recipes_path, params: {
        recipe: {
          name: "My API App",
          description: "A cool API app",
          api_flag: "--api --skip-turbo",
          ui_state: "{}"
        }
      }
    end

    assert_equal "published", Recipe.last.status
  end

  test "create allows duplicate recipes with same CLI flags and ingredients for a different user" do
    sign_out @user
    sign_in users(:jane)

    assert_difference("Recipe.count") do
      post recipes_path, params: {
        recipe: {
          name: @recipe.name,
          description: @recipe.description,
          api_flag: @recipe.cli_flags,
          ui_state: "{}"
        }
      }
    end

    new_recipe = Recipe.last

    assert_equal @recipe.name, new_recipe.name
    assert_equal @recipe.description, new_recipe.description
    assert_equal @recipe.cli_flags, new_recipe.cli_flags
  end

  test "create prevents duplicate recipes with same CLI flags and ingredients for the same user" do
    janes_recipe = recipes(:basic_recipe)

    assert_difference("Recipe.count") do
      post recipes_path, params: {
        recipe: {
          name: janes_recipe.name,
          description: janes_recipe.description,
          status: janes_recipe.status,
          rails_flags: janes_recipe.cli_flags,
          ingredient_ids: janes_recipe.ingredient_ids,
          ui_state: "{}"
        }
      }
    end

    first_recipe = Recipe.last
    assert_equal janes_recipe.name, first_recipe.name
    assert_equal janes_recipe.cli_flags, first_recipe.cli_flags
    assert_equal janes_recipe.ingredient_ids, first_recipe.ingredient_ids
    assert_redirected_to recipe_path(first_recipe)

    assert_no_difference("Recipe.count") do
      post recipes_path, params: {
        recipe: {
          name: janes_recipe.name,
          description: janes_recipe.description,
          status: janes_recipe.status,
          api_flag: janes_recipe.cli_flags,
          ingredient_ids: janes_recipe.ingredient_ids,
          ui_state: "{}"
        }
      }
    end

    assert_redirected_to recipe_path(existing_recipe = first_recipe)
    assert_equal "A recipe with these settings already exists", flash[:alert]
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

    assert_response :see_other
  end

  test "create with invalid status fails validation" do
    assert_no_difference("Recipe.count") do
      post recipes_path, params: {
        recipe: {
          name: "My App",
          description: "A description",
          status: "invalid_status",
          api_flag: "--api --skip-turbo",
          ui_state: "{}"
        }
      }
    end

    assert_response :see_other
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

    assert_response :see_other
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

  test "update successfully updates recipe attributes" do
    patch recipe_path(@recipe), params: {
      recipe: {
        name: "Updated Recipe Name",
        description: "Updated description",
        status: "archived",
        api_flag: "--api",
        database_choice: "--database=postgresql",
        javascript_choice: "--javascript=esbuild",
        css_choice: "--css=tailwind",
        rails_flags: "--skip-test",
        ui_state: '{"some":"updated_value"}'
      }
    }

    @recipe.reload
    assert_equal "Updated Recipe Name", @recipe.name
    assert_equal "Updated description", @recipe.description
    assert_equal "archived", @recipe.status
    assert_equal "--api --database=postgresql --javascript=esbuild --css=tailwind --skip-test", @recipe.cli_flags
    assert_equal({ "some" => "updated_value" }, @recipe.ui_state)

    assert_redirected_to recipe_path(@recipe)
    assert_equal "Recipe was successfully updated.", flash[:notice]
  end

  test "update enqueues WriteRecipeJob" do
    assert_enqueued_with(job: WriteRecipeJob) do
      patch recipe_path(@recipe), params: {
        recipe: {
          name: "Job Test Recipe",
          description: "Testing job enqueuing",
          ui_state: "{}"
        }
      }
    end

    # Verify the job is enqueued with the correct parameters
    assert_enqueued_with(
      job: WriteRecipeJob,
      args: [ {
        recipe_id: @recipe.id,
        user_id: @user.id
      } ]
    )
  end

  test "update requires authentication" do
    sign_out @user
    patch recipe_path(@recipe), params: {
      recipe: {
        name: "Should Not Update",
        ui_state: "{}"
      }
    }
    assert_redirected_to root_path

    @recipe.reload
    assert_not_equal "Should Not Update", @recipe.name
  end

  test "update prevents modifying other user's recipes" do
    patch recipe_path(@other_users_recipe), params: {
      recipe: {
        name: "Should Not Update",
        ui_state: "{}"
      }
    }
    assert_response :not_found

    @other_users_recipe.reload
    assert_not_equal "Should Not Update", @other_users_recipe.name
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
            ingredient_ids: [ ingredient.id ],
            ui_state: "{}"
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
            ui_state: "{}",
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
            ui_state: "{}",
            ingredient_ids: [ auth.id, 999999 ]
          }
        }
      end
    end

    recipe = Recipe.last
    assert_equal "Mixed Recipe", recipe.name
    assert_equal "Recipe with mix of real and fake ingredients", recipe.description
    assert_equal "--api", recipe.cli_flags
    assert_equal "published", recipe.status
    assert_includes recipe.ingredients, auth
    assert_equal 1, recipe.ingredients.count
    assert_equal [ auth.id ], recipe.ingredient_ids
    assert_redirected_to recipe_path(recipe)
    assert_equal "Recipe was successfully created.", flash[:notice]
  end
end
