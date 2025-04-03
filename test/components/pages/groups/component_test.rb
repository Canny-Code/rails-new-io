# frozen_string_literal: true

require "test_helper"
require "support/phlex_component_test_case"

module Pages
  module Groups
    class ComponentTest < PhlexComponentTestCase
      test "renders group with stimulus attributes" do
        page = pages(:basic_setup)
        group = Group.new(title: "Test Group", behavior_type: "generic_checkbox", page:)
        sub_group = group.sub_groups.build(title: "Default")
        sub_group.elements.build(
          label: "Test Element",
          user: users(:john),
          position: 0,
          variant: Element::RailsFlagCheckbox.new(checked: false)
        )

        Current.user = users(:john)

        group.stubs(:stimulus_attributes).returns({
          controller: "rails-flag-checkbox",
          "rails-flag-checkbox-generated-output-outlet": "#rails-flags"
        })
        Element.stubs(:visible_for_user?).returns(true)

        component = Component.new(group: group)
        html = component.render_in(view_context)

        assert_includes html, 'data-controller="rails-flag-checkbox"'
        assert_includes html, 'data-rails-flag-checkbox-generated-output-outlet="#rails-flags"'
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
