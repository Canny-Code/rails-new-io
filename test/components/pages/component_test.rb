require "test_helper"
require "mocha/minitest"

module Pages
  class ComponentTest < ActiveSupport::TestCase
    include Phlex::Testing::ViewHelper
    include ActionView::Helpers::AssetTagHelper
    include Rails.application.routes.url_helpers
    include Mocha::API

    def default_url_options
      { host: "example.com" }
    end

    test "renders empty state when page has no groups" do
      page = Minitest::Mock.new
      page.expect :groups, []

      Current.stubs(:user).returns(nil)
      Pages::Component.any_instance.stubs(:new_ingredient_path).returns("/ingredients/new")

      # Create a simple Phlex component for empty state
      empty_state_component = Class.new(Phlex::HTML) do
        def view_template
          div { plain "No ingredients yet" }
        end
      end.new

      EmptyState::Component.stubs(:new)
        .with(
          user: nil,
          title: "No ingredients yet",
          description: "Get started by adding your first ingredient.",
          button_text: "Add new Ingredient",
          button_path: "/ingredients/new",
          icon: true,
          emoji: "🧂"
        )
        .returns(empty_state_component)

      component = Component.new(page: page)
      html = render component

      assert_includes html, "No ingredients yet"
      assert_includes html, "bg-white rounded-lg border border-gray-200"
    end
  end
end
