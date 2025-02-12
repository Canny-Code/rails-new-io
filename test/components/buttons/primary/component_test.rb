require "test_helper"
require "support/phlex_component_test_case"

module Buttons
  module Primary
    class ComponentTest < PhlexComponentTestCase
      test "renders button with icon by default" do
        component = Component.new(text: "Create App", path: "/apps/new")
        result = component.render_in(view_context)
        doc = Nokogiri::HTML.fragment(result)

        assert_equal "Create App", doc.text.strip
        assert doc.css("svg").any?, "Expected an icon to be present"
        assert_includes doc.css("a").first["class"], "bg-[#993351]"
        assert_equal "/apps/new", doc.css("a").first["href"]
      end

      test "renders button without icon" do
        component = Component.new(text: "Create App", path: "/apps/new", icon: false)
        result = component.render_in(view_context)
        doc = Nokogiri::HTML.fragment(result)

        assert_equal "Create App", doc.text.strip
        assert_empty doc.css("svg"), "Expected no icon to be present"
      end

      test "renders disabled button" do
        component = Component.new(text: "Create App", path: "/apps/new", disabled: true)
        result = component.render_in(view_context)
        doc = Nokogiri::HTML.fragment(result)

        link = doc.css("a").first
        assert_includes link["class"], "disabled:bg-[#D3A9B6]"
        assert_includes link["class"], "disabled:cursor-not-allowed"
      end

      test "renders button with custom data attributes" do
        component = Component.new(
          text: "Create App",
          path: "/apps/new",
          data: { controller: "button", action: "click->button#click" }
        )
        result = component.render_in(view_context)
        doc = Nokogiri::HTML.fragment(result)

        link = doc.css("a").first
        assert_equal "button", link["data-controller"]
        assert_equal "click->button#click", link["data-action"]
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
  end
end
