require "test_helper"

module Pages
  module Groups
    module SubGroups
      module Elements
        module TextField
          class ComponentTest < ActiveSupport::TestCase
            include Phlex::Testing::ViewHelper

            test "initializes with required attributes" do
              component = Component.new(
                label: "App Name",
                description: "Your application name",
                name: "app_name"
              )

              assert_equal "App Name", component.instance_variable_get(:@label)
              assert_equal "Your application name", component.instance_variable_get(:@description)
              assert_equal "app_name", component.instance_variable_get(:@name)
              assert_equal({}, component.instance_variable_get(:@data))
            end

            test "initializes with optional data attribute" do
              component = Component.new(
                label: "App Name",
                description: "Your application name",
                name: "app_name",
                data: { controller: "text-field" }
              )

              assert_equal({ controller: "text-field" }, component.instance_variable_get(:@data))
            end

            test "renders a text field" do
              component = Component.new(
                label: "App Name",
                description: "Your application name",
                name: "app_name"
              )

              html = render component

              assert_includes html, "TODO: Implement Text Field"
            end
          end
        end
      end
    end
  end
end
