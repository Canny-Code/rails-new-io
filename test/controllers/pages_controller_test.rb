require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  def setup
    @page = pages(:basic_setup)
    @recipe = recipes(:blog_recipe)
    sign_in users(:jane)
  end

  test "renders page content successfully" do
    get setup_recipes_path(slug: "basic-setup")
    assert_response :success
    assert_select "h3", "Databases"
  end

  test "edit action retrieves page with nested associations" do
    get edit_recipes_path(recipe_id: @recipe.id, slug: @page.slug)
    assert_response :success

    # Instead of checking assigns, verify content in the response
    assert_match @page.slug, response.body
    assert_select "input#recipe_name[value=?]", @recipe.name
  end

  test "edit action with invalid slug returns 404" do
    get edit_recipes_path(recipe_id: @recipe.id, slug: "nonexistent-page")

    assert_response :not_found
  end

  test "edit action with invalid recipe_id returns 404" do
      get edit_recipes_path(recipe_id: -1, slug: @page.slug)

      assert_response :not_found
  end

  test "edit action requires authentication" do
    sign_out users(:jane)
    get edit_recipes_path(recipe_id: @recipe.id, slug: @page.slug)
    assert_redirected_to root_path
  end
end
