require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  def setup
    @page = pages(:basic_setup)
  end

  test "should include all nested associations" do
    get page_path(@page)
    assert_response :success

    assert_includes response.body, "TODO: Implement Text Field"
  end
end
