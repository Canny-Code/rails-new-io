require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  def setup
    @page = pages(:basic_setup)
    sign_in users(:jane)
  end

  test "renders page content successfully" do
    get setup_recipes_path(slug: "basic-setup")
    assert_response :success
    assert_select "h3", "Databases"
  end
end
