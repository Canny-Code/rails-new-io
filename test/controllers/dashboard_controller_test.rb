require "test_helper"

class DashboardControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:jane)
    sign_in @user

    @blog_app = generated_apps(:blog_app)
    @saas_app = generated_apps(:saas_starter)
    @api_app = generated_apps(:api_project)
  end

  test "should get index" do
    get dashboard_url
    assert_response :success
  end

  test "filters by status" do
    get dashboard_url, params: { status: "completed" }
    assert_response :success

    assert_select "td", text: "personal-blog"
    assert_select "td", text: "saas-starter", count: 0
    assert_select "td", text: "inventory-api", count: 0
  end

  test "searches by name" do
    get dashboard_url, params: { search: "inventory" }
    assert_response :success

    assert_select "td", text: "inventory-api"
    assert_select "td", text: "personal-blog", count: 0
    assert_select "td", text: "saas-starter", count: 0
  end

  test "sorts by column" do
    get dashboard_url, params: { sort: "name", direction: "asc" }
    assert_response :success

    assert_select "tr td:first-child" do |elements|
      names = elements.map(&:text)
      assert_equal names.sort, names, "Names should be in alphabetical order"
    end
  end

  test "combines filters, search and sort" do
    get dashboard_url, params: {
      status: "failed",
      search: "api",
      sort: "created_at",
      direction: "desc"
    }
    assert_response :success

    # Should show both failed APIs but not the completed one
    assert_select "td", text: "weather-api"      # Created 1 day ago
    assert_select "td", text: "inventory-api"    # Created 2 days ago
    assert_select "td", text: "payment-api", count: 0  # This one is completed, shouldn't show

    # Verify order (created_at desc)
    rows = css_select("tr td:first-child").map(&:text)
    assert_equal [ "weather-api", "inventory-api" ], rows,
      "Failed APIs should be ordered by created_at desc"
  end
end
