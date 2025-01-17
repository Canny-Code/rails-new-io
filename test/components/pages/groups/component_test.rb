# frozen_string_literal: true

require "test_helper"
require "support/phlex_component_test_case"

module Pages
  module Groups
    class ComponentTest < PhlexComponentTestCase
      test "renders group with stimulus attributes" do
        group = Group.new(title: "Test Group", behavior_type: "generic_checkbox")
        group.stubs(:stimulus_attributes).returns({
          controller: "rails-flag-checkbox",
          "rails-flag-checkbox-generated-output-outlet": "#rails-flags"
        })
        group.stubs(:sub_groups).returns([])

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
