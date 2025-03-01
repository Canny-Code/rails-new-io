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

  test "should create ingredient with multiple snippets" do
    assert_difference("Ingredient.count") do
      post ingredients_url, params: {
        ingredient: {
          name: "Ingredient With Snippets",
          template_content: "gem 'test'",
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
        new_snippets: [ "additional snippet" ]
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
    DeleteIngredientJob.any_instance.stubs(:perform_later)

    assert_difference("Ingredient.count", -1) do
      delete ingredient_url(@ingredient)
    end

    assert_redirected_to ingredients_url
  end
end
