require "test_helper"
require "support/phlex_component_test_case"

class ResourceLayout::ComponentTest < PhlexComponentTestCase
  include Rails.application.routes.url_helpers
  include ActionView::TestCase::Behavior

  test "renders empty state when no resources are present" do
    empty_state = Class.new(ApplicationComponent) do
      def view_template
        div(class: "p-8 text-center") { "No items found" }
      end
    end.new

    component = ResourceLayout::Component.new(
      title: "Test Resources",
      subtitle: "Test subtitle",
      resources: [],
      columns: [],
      empty_state: empty_state
    )

    render component

    assert_select "div", text: "No items found"
    assert_select "h1", text: "Test Resources"
    assert_select "p", text: "Test subtitle"
  end
end
