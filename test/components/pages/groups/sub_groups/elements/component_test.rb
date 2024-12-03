require "test_helper"

module Pages
  module Groups
    module SubGroups
      module Elements
        class ComponentTest < ActiveSupport::TestCase
          include Phlex::Testing::ViewHelper
          include ActionView::Helpers::AssetTagHelper
          include Rails.application.routes.url_helpers

          def default_url_options
            { host: "example.com" }
          end

          test "renders radio button element" do
            element = elements(:database_postgresql)
            component = Component.new(element: element)

            html = render component

            assert_includes html, "input type=\"radio\""
            assert_includes html, element.label
          end

          test "renders checkbox element" do
            element = elements(:skip_action_mailer)
            component = Component.new(element: element)

            html = render component

            assert_includes html, "input type=\"checkbox\""
            assert_includes html, element.label
          end

          test "renders text field element" do
            element = elements(:app_name)
            component = Component.new(element: element)

            html = render component

            assert_includes html, "TODO: Implement Text Field"
          end

          test "raises error for unknown element type" do
            element = Minitest::Mock.new
            element.expect :variant_type, "Element::Unknown"
            element.expect :variant_type, "Element::Unknown" # Called twice due to error message

            error = assert_raises(RuntimeError) do
              render Component.new(element: element)
            end

            assert_equal "Unknown element variant_type: Element::Unknown", error.message
          end
        end
      end
    end
  end
end
