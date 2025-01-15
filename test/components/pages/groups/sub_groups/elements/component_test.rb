require "test_helper"
require "support/phlex_component_test_case"

module Pages
  module Groups
    module SubGroups
      module Elements
        class ComponentTest < PhlexComponentTestCase
          test "group_stimulus_attributes transforms controller key to action" do
            group = mock
            group.stubs(:stimulus_attributes).returns({
              "controller" => "check-box",
              "check-box-generated-output-outlet" => "#rails-flags"
            })

            sub_group = mock
            sub_group.stubs(:group).returns(group)

            element = mock
            element.stubs(:sub_group).returns(sub_group)

            component = Component.new(element: element)

            result = component.send(:group_stimulus_attributes)

            # The original stimulus_attributes has "controller", but it should be transformed to "action"
            assert_equal "check-box", result["action"]
            assert_not_includes result.keys, "controller"
          end

          test "raises error for unknown element variant type" do
            element = mock
            element.stubs(:variant_type).returns("Element::Unknown")

            component = Component.new(element: element)

            error = assert_raises(RuntimeError) do
              component.view_template
            end

            assert_equal "Unknown element variant_type: Element::Unknown", error.message
          end
        end
      end
    end
  end
end
