require "test_helper"

class IngredientsControllerTest < ActionDispatch::IntegrationTest
  setup do
    # Mock repository operations
    DataRepositoryService.any_instance.stubs(:push_app_files).returns(true)
    DataRepositoryService.any_instance.stubs(:initialize_repository).returns(true)

    # Mock GitHub API calls
    mock_client = mock("octokit_client")
    ref_response = Data.define(:object).new(object: Data.define(:sha).new(sha: "old_sha"))
    commit_tree = Data.define(:sha).new(sha: "tree_sha")
    commit_data = Data.define(:tree).new(tree: commit_tree)
    commit = Data.define(:commit, :sha).new(commit: commit_data, sha: "old_sha")
    new_tree = Data.define(:sha).new(sha: "new_tree_sha")
    new_commit = Data.define(:sha).new(sha: "new_sha")

    mock_client.stubs(:ref).returns(ref_response)
    mock_client.stubs(:commit).returns(commit)
    mock_client.stubs(:create_tree).returns(new_tree)
    mock_client.stubs(:create_commit).returns(new_commit)
    mock_client.stubs(:update_ref).returns(true)
    mock_client.stubs(:repository?).returns(true)

    Octokit::Client.stubs(:new).returns(mock_client)

    @ingredient = ingredients(:rails_authentication)
    @user = users(:john)
    @other_user = users(:jane)
    sign_in @user
  end

  def teardown
    super
    Mocha::Mockery.instance.teardown
    Mocha::Mockery.instance.stubba.unstub_all
  end

  test "should get index" do
    get ingredients_url
    assert_response :success
  end

  test "should get new" do
    get new_ingredient_url
    assert_response :success
  end

  test "should create ingredient and enqueue WriteIngredientJob" do
    assert_difference("Ingredient.count") do
      post ingredients_url, params: {
        ingredient: {
          name: "Test Ingredient",
          description: "A test ingredient",
          template_content: "gem 'test'",
          page_id: pages(:custom_ingredients).id,
          category: "Testing",
          conflicts_with: [],
          requires: [],
          configures_with: {}
        }
      }
    end

    new_ingredient = @controller.instance_variable_get(:@ingredient)
    assert new_ingredient.persisted?
    assert_equal "Test Ingredient", new_ingredient.name
    assert_equal "A test ingredient", new_ingredient.description
    assert_equal "gem 'test'", new_ingredient.template_content
    assert_equal "Testing", new_ingredient.category
    assert_equal @user.id, new_ingredient.created_by_id

    assert_enqueued_with(
      job: WriteIngredientJob,
      args: [ {
        ingredient_id: new_ingredient.id,
        user_id: @user.id
      } ]
    )

    assert_redirected_to ingredient_url(Ingredient.last)
    assert_equal "Ingredient was successfully created.", flash[:notice]
  end

  test "should not create ingredient with duplicate name, page and category for same user" do
    assert_no_difference("Ingredient.count") do
      post ingredients_url, params: {
        ingredient: {
          name: @ingredient.name,
          page: @ingredient.page,
          category: @ingredient.category,
          description: "A different description",
          page_id: pages(:custom_ingredients).id,
          template_content: "gem 'something_else'"
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
          page_id: pages(:custom_ingredients).id,
          template_content: "gem 'something_else'",
          category: "Testing"
        }
      }
    end

    assert_redirected_to ingredient_url(Ingredient.last)
    assert_equal @ingredient.name, Ingredient.last.name
    assert_not_equal @ingredient.created_by_id, Ingredient.last.created_by_id
  end

  test "should create ingredient with the same name for different category and page for the same user" do
    assert_difference("Ingredient.count") do
      post ingredients_url, params: {
        ingredient: {
          name: @ingredient.name,
          category: "Different Category",
          page: pages(:frontend),
          description: "A different description",
          page_id: pages(:custom_ingredients).id,
          template_content: "gem 'something_else'"
        }
      }
    end

    assert_redirected_to ingredient_url(Ingredient.last)
    assert_equal "Ingredient was successfully created.", flash[:notice]
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

  test "should create ingredient with multiple snippets" do
    assert_difference("Ingredient.count") do
      post ingredients_url, params: {
        ingredient: {
          name: "Ingredient With Snippets",
          template_content: "gem 'test'",
          category: "Testing",
          page_id: pages(:custom_ingredients).id,
          new_snippets: [ "puts 'First snippet'", "puts 'Second snippet'" ]
        }
      }
    end

    new_ingredient = Ingredient.find_by(name: "Ingredient With Snippets")
    assert_equal [ "puts 'First snippet'", "puts 'Second snippet'" ], new_ingredient.snippets
    assert_redirected_to ingredient_url(new_ingredient)
  end

  test "should update ingredient with new snippets" do
    @ingredient.update(snippets: [ "existing snippet" ])

    patch ingredient_url(@ingredient), params: {
      ingredient: {
        template_content: @ingredient.template_content,
        new_snippets: [ "existing snippet", "additional snippet" ]
      }
    }

    @ingredient.reload
    assert_equal [ "existing snippet", "additional snippet" ], @ingredient.snippets
    assert_redirected_to ingredient_url(@ingredient)
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

  test "should not update ingredient with duplicate name, page and category for same user" do
    other_ingredient = ingredients(:basic)  # Another ingredient from the same user (john)

    patch ingredient_url(@ingredient), params: {
      ingredient: {
        name: other_ingredient.name,
        page: other_ingredient.page,
        category: other_ingredient.category,
        template_content: @ingredient.template_content
      }
    }

    assert_response :unprocessable_entity
    assert_includes @response.body, "Name has already been taken"

    @ingredient.reload
    assert_not_equal other_ingredient.name, @ingredient.name
  end

  test "should destroy ingredient" do
    DeleteIngredientJob.any_instance.stubs(:perform_later)

    assert_difference("Ingredient.count", -1) do
      delete ingredient_url(@ingredient)
    end

    assert_redirected_to ingredients_url
  end

  test "should not create ingredient without category" do
    assert_no_difference("Ingredient.count") do
      post ingredients_url, params: {
        ingredient: {
          name: "Test Ingredient",
          description: "A test ingredient",
          template_content: "gem 'test'"
          # category intentionally omitted
        }
      }
    end

    assert_response :unprocessable_entity
    assert_includes @response.body, "Category can&#39;t be blank"
  end

  test "should not allow non-owner to edit ingredient" do
    ingredient = ingredients(:rails_authentication)
    sign_in users(:jane)

    get edit_ingredient_url(ingredient)
    assert_redirected_to ingredient_url(ingredient)
    assert_equal "You can only perform this action on your own ingredients!", flash[:notice]
  end

  test "should not allow non-owner to update ingredient" do
    ingredient = ingredients(:rails_authentication)
    sign_in users(:jane)

    patch ingredient_url(ingredient), params: { ingredient: { name: "New Name" } }
    assert_redirected_to ingredient_url(ingredient)
    assert_equal "You can only perform this action on your own ingredients!", flash[:notice]
  end

  test "should not allow non-owner to destroy ingredient" do
    ingredient = ingredients(:rails_authentication)
    sign_in users(:jane)

    assert_no_difference("Ingredient.count") do
      delete ingredient_url(ingredient)
    end
    assert_redirected_to ingredient_url(ingredient)
    assert_equal "You can only perform this action on your own ingredients!", flash[:notice]
  end

  test "should allow rails-new-io user to edit any ingredient" do
    ingredient = ingredients(:rails_authentication)
    sign_in users(:rails_new_io)

    get edit_ingredient_url(ingredient)
    assert_response :success
  end

  test "should allow rails-new-io user to update any ingredient" do
    ingredient = ingredients(:rails_authentication)
    sign_in users(:rails_new_io)

    patch ingredient_url(ingredient), params: { ingredient: { name: "New Name" } }
    assert_redirected_to ingredient_url(ingredient)
    assert_equal "Ingredient was successfully updated.", flash[:notice]
  end

  test "should allow rails-new-io user to destroy any ingredient" do
    ingredient = ingredients(:rails_authentication)
    sign_in users(:rails_new_io)

    assert_difference("Ingredient.count", -1) do
      delete ingredient_url(ingredient)
    end
    assert_redirected_to ingredients_url
    assert_equal "Ingredient was successfully deleted.", flash[:notice]
  end

  test "should handle IngredientUiCreationError and destroy ingredient" do
    # Stub IngredientUiCreator to raise an error
    IngredientUiCreator.stubs(:call).raises(IngredientUiCreationError.new("Test error"))

    assert_no_difference("Ingredient.count") do
      post ingredients_url, params: {
        ingredient: {
          name: "Test Ingredient",
          description: "A test ingredient",
          template_content: "gem 'test'",
          page_id: pages(:custom_ingredients).id,
          category: "Testing",
          sub_category: "Default",
          new_snippets: [ "puts 'test'" ]
        }
      }
    end

    assert_response :unprocessable_entity
    assert_equal "There was a problem creating the ingredient. Please try again or contact support if the problem persists.", flash[:alert]
  end

  test "should create ingredient with onboarding step" do
    assert_difference("Ingredient.count") do
      post ingredients_url, params: {
        ingredient: {
          name: "Test Ingredient",
          description: "A test ingredient",
          template_content: "gem 'test'",
          page_id: pages(:custom_ingredients).id,
          category: "Testing",
          conflicts_with: [],
          requires: [],
          configures_with: {}
        },
        onboarding_step: 1
      }
    end

    new_ingredient = @controller.instance_variable_get(:@ingredient)
    assert_redirected_to ingredient_path(new_ingredient, onboarding_step: 2)
  end
end
