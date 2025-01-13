require "test_helper"

class PagesControllerTest < ActionController::TestCase
  def setup
    @page = pages(:basic_setup)
  end

  test "renders page content successfully" do
    get :show, params: { slug: @page.slug }
    assert_response :success
    assert_select "h3", "Databases"
  end

  test "finds page by slug" do
    get :show, params: { slug: "basic-setup" }
    assert_response :success
    assert_select "h3", "Databases"
  end
end
