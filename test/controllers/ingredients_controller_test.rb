require "test_helper"

class IngredientsControllerTest < ActionDispatch::IntegrationTest
  setup do
    # Mock git operations
    GitRepo.any_instance.stubs(:commit_changes).returns(true)
    GitRepo.any_instance.stubs(:push_changes).returns(true)

    @user = users(:john)
    @other_user = users(:jane)
    @ingredient = ingredients(:rails_authentication)
    sign_in @user
  end

  test "should get index" do
    get ingredients_url
    assert_response :success
  end

  test "should get new" do
    get new_ingredient_url
    assert_response :success
  end

  test "should create ingredient" do
    assert_difference("Ingredient.count") do
      post ingredients_url, params: {
        ingredient: {
          name: "Test Ingredient",
          description: "A test ingredient",
          template_content: "gem 'test'",
          category: "Testing",
          conflicts_with: [],
          requires: [],
          configures_with: {}
        }
      }
    end

    assert_redirected_to ingredient_url(Ingredient.last)
  end

  test "should not create ingredient with duplicate name for same user" do
    assert_no_difference("Ingredient.count") do
      post ingredients_url, params: {
        ingredient: {
          name: @ingredient.name,  # Using existing ingredient's name
          description: "A different description",
          template_content: "gem 'something_else'",
          category: "Testing"
        }
      }
    end

    assert_response :unprocessable_entity
    assert_includes @response.body, "Name has already been taken"
  end

  test "should create ingredient with same name for different user" do
    sign_out @user
    sign_in @other_user

    assert_difference("Ingredient.count") do
      post ingredients_url, params: {
        ingredient: {
          name: @ingredient.name,  # Using existing ingredient's name
          description: "A different description",
          template_content: "gem 'something_else'",
          category: "Testing"
        }
      }
    end

    assert_redirected_to ingredient_url(Ingredient.last)
    assert_equal @ingredient.name, Ingredient.last.name
    assert_not_equal @ingredient.created_by_id, Ingredient.last.created_by_id
  end

  test "should show ingredient" do
    get ingredient_url(@ingredient)
    assert_response :success
  end

  test "should get edit" do
    get edit_ingredient_url(@ingredient)
    assert_response :success
  end

  test "should update ingredient" do
    patch ingredient_url(@ingredient), params: {
      ingredient: {
        name: "Updated Name",
        description: "Updated description",
        template_content: @ingredient.template_content
      }
    }
    assert_redirected_to ingredient_url(@ingredient)
    @ingredient.reload
    assert_equal "Updated Name", @ingredient.name
  end

  test "should not update ingredient with invalid params" do
    original_name = @ingredient.name

    patch ingredient_url(@ingredient), params: {
      ingredient: {
        name: "",  # Name is required
        template_content: ""  # Template content is required
      }
    }

    assert_response :unprocessable_entity
    assert_includes @response.body, "can&#39;t be blank"  # HTML-encoded apostrophe
    assert_includes @response.body, "2 errors prohibited this ingredient from being saved"

    @ingredient.reload
    assert_equal original_name, @ingredient.name
  end

  test "should not update ingredient with duplicate name for same user" do
    other_ingredient = ingredients(:basic)  # Another ingredient from the same user (john)

    patch ingredient_url(@ingredient), params: {
      ingredient: {
        name: other_ingredient.name,  # Try to use another ingredient's name
        template_content: @ingredient.template_content  # Keep the required field
      }
    }

    assert_response :unprocessable_entity
    assert_includes @response.body, "Name has already been taken"

    @ingredient.reload
    assert_not_equal other_ingredient.name, @ingredient.name
  end

  test "should destroy ingredient" do
    assert_difference("Ingredient.count", -1) do
      delete ingredient_url(@ingredient)
    end

    assert_redirected_to ingredients_url
  end
end
