require "test_helper"
require "support/phlex_component_test_case"

class OnboardingSidebarStepTest < PhlexComponentTestCase
  test "renders completed step" do
    component = OnboardingSidebarStep::Component.new(
      title: "Test Step",
      description: "Test Description",
      completed: true
    )
    result = component.render_in(view_context)
    doc = Nokogiri::HTML.fragment(result)

    assert doc.css("li.relative.pb-10").any?
    assert doc.css("div.bg-\\[\\#008A05\\]").any?
    assert doc.css("span.bg-\\[\\#008A05\\]").any?
    assert doc.css("svg.text-white").any?
    assert_equal "Test Step", doc.css("span.text-sm.font-medium").text.strip
    assert_equal "Test Description", doc.css("div.text-sm.text-gray-500").text.strip
  end

  test "renders incomplete step" do
    component = OnboardingSidebarStep::Component.new(
      title: "Test Step",
      description: "Test Description",
      completed: false
    )
    result = component.render_in(view_context)
    doc = Nokogiri::HTML.fragment(result)

    assert doc.css("li.relative.pb-10").any?
    assert doc.css("div.bg-gray-300").any?
    assert doc.css("span.border-gray-300").any?
    assert_equal "Test Step", doc.css("span.text-sm.font-medium").text.strip
    assert_equal "Test Description", doc.css("div.text-sm.text-gray-500").text.strip
  end

  test "renders current step" do
    component = OnboardingSidebarStep::Component.new(
      title: "Test Step",
      description: "Test Description",
      current: true
    )
    result = component.render_in(view_context)
    doc = Nokogiri::HTML.fragment(result)

    assert doc.css("li.relative.pb-10").any?
    assert doc.css("div.bg-gray-300").any?
    assert doc.css("span.border-2.border-\\[\\#008A05\\]").any?
    assert doc.css("span.bg-\\[\\#008A05\\]").any?
    assert_equal "Test Step", doc.css("span.text-sm.font-medium").text.strip
    assert_equal "Test Description", doc.css("div.text-sm.text-gray-500").text.strip
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
