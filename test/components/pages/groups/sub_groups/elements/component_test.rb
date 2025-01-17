# frozen_string_literal: true

require "test_helper"
require "support/phlex_component_test_case"

module Pages
  module Groups
    module SubGroups
      module Elements
        class ComponentTest < PhlexComponentTestCase
          test "transforms stimulus attributes for checkbox" do
            group = Group.new(behavior_type: "generic_checkbox")
            group.stubs(:stimulus_attributes).returns({
              "controller" => "rails-flag-checkbox",
              "rails-flag-checkbox-generated-output-outlet" => "#rails-flags"
            })

            sub_group = SubGroup.new(group: group)
            element = Element.new(sub_group: sub_group)
            element.stubs(:variant_type).returns("Element::RailsFlagCheckbox")
            element.stubs(:variant).returns(Element::RailsFlagCheckbox.new)

            component = Component.new(element: element)
            result = component.send(:group_stimulus_attributes)

            assert_equal "rails-flag-checkbox", result["action"]
            assert_equal "#rails-flags", result["rails-flag-checkbox-generated-output-outlet"]
          end
        end
      end
    end
  end
end
