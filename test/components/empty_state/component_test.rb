require "test_helper"
require "support/phlex_component_test_case"

class EmptyState::ComponentTest < PhlexComponentTestCase
  def setup
    @user = users(:john)
    @params = {
      user: @user,
      title: "No items found",
      description: "Get started by creating your first item",
      button_text: "Add Item",
      button_path: "/items/new",
      emoji: "🎉"
    }
  end

  def test_renders_component_with_all_attributes
    component = EmptyState::Component.new(**@params)
    result = component.render_in(view_context)

    # Test content
    assert_includes result, "No items found"
    assert_includes result, "Get started by creating your first item"
    assert_includes result, "Add Item"
    assert_includes result, "🎉"

    # Test structure and classes
    doc = Nokogiri::HTML.fragment(result)
    assert_includes doc.css("div").first["class"], "bg-white"
    assert_includes doc.css("div")[1]["class"], "bg-gray-50"
    assert_includes doc.css("h3").first["class"], "text-gray-900"
    assert_includes doc.css("p").first["class"], "text-gray-500"

    # Test link
    link = doc.css("a").first
    assert_equal "/items/new", link["href"]
    assert_includes link["class"], "bg-[#ac3b61]"

    # Test SVG
    svg = doc.css("svg").first
    assert_equal "0 0 20 20", svg["viewbox"]

    path = doc.css("path").first
    assert_equal "M10.75 4.75a.75.75 0 0 0-1.5 0v4.5h-4.5a.75.75 0 0 0 0 1.5h4.5v4.5a.75.75 0 0 0 1.5 0v-4.5h4.5a.75.75 0 0 0 0-1.5h-4.5v-4.5Z", path["d"]
  end

  def test_renders_with_different_content
    params = @params.merge(
      title: "Different title",
      description: "Different description",
      button_text: "Different button",
      button_path: "/different/path",
      emoji: "⭐"
    )

    result = EmptyState::Component.new(**params).render_in(view_context)

    assert_includes result, "Different title"
    assert_includes result, "Different description"
    assert_includes result, "Different button"
    assert_includes result, "⭐"

    doc = Nokogiri::HTML.fragment(result)
    link = doc.css("a").first
    assert_equal "/different/path", link["href"]
  end

  def test_hover_and_focus_states_classes_present
    result = EmptyState::Component.new(**@params).render_in(view_context)

    doc = Nokogiri::HTML.fragment(result)
    link = doc.css("a").first
    assert_includes link["class"], "hover:bg-[#993351]"
    assert_includes link["class"], "focus-visible:outline"
    assert_includes link["class"], "focus-visible:outline-2"
    assert_includes link["class"], "focus-visible:outline-offset-2"
    assert_includes link["class"], "focus-visible:outline-[#993351]"
  end

  private

  def view_context
    controller.view_context
  end

  def controller
    @controller ||= ApplicationController.new.tap do |c|
      c.request = ActionDispatch::TestRequest.create
      c.response = ActionDispatch::TestResponse.new
    end
  end
end
