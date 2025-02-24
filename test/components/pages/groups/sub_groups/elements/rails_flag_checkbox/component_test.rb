# frozen_string_literal: true

require "test_helper"
require "support/phlex_component_test_case"

module Pages
  module Groups
    module SubGroups
      module Elements
        module RailsFlagCheckbox
          class ComponentTest < PhlexComponentTestCase
            def test_renders_checkbox_with_stimulus_controller
              component = Component.new(**build_params)
              result = component.render_in(view_context)
              doc = Nokogiri::HTML.fragment(result)

              # Test checkbox attributes
              checkbox = doc.css("input[type='checkbox']").first
              assert_equal "checked", checkbox["data-display-when"]
              assert_equal "skip_git", checkbox["name"]
              assert_equal "--skip-git", checkbox["value"]
              assert_equal "rails-flag-checkbox", checkbox["data-controller"]
              assert_equal "#rails-flags", checkbox["data-rails-flag-checkbox-generated-output-outlet"]
              assert_equal "change->rails-flag-checkbox#update change->recipe-ui-state-store#railsFlagChanged", checkbox["data-action"]
              assert_equal "12345", checkbox["data-element-id"]
            end

            def test_renders_checkbox_with_custom_outlet
              params = build_params(data: { "rails-flag-checkbox-generated-output-outlet" => "#custom_ingredients" })
              result = Component.new(**params).render_in(view_context)
              doc = Nokogiri::HTML.fragment(result)

              input_element = doc.css("input[type='checkbox']").first
              assert_equal "#custom_ingredients", input_element["data-rails-flag-checkbox-generated-output-outlet"]
            end

            def test_renders_checkbox_with_custom_data_attributes
              custom_data = { "action" => "click->some-controller#action" }
              params = build_params(data: custom_data)

              result = Component.new(**params).render_in(view_context)
              doc = Nokogiri::HTML.fragment(result)

              checkbox = doc.css("input[type='checkbox']").first
              assert_equal "click->some-controller#action", checkbox["data-action"]
            end

            private

            def build_params(**options)
              {
                label: "Skip Git",
                description: "Skip Git files",
                image_path: nil,
                name: "skip_git",
                command_line_value: "--skip-git",
                checked: false,
                display_when: "checked",
                data: {
                  controller: "rails-flag-checkbox",
                  "rails-flag-checkbox-generated-output-outlet": "#rails-flags",
                  action: "change->rails-flag-checkbox#update change->recipe-ui-state-store#railsFlagChanged",
                  element_id: "12345"
                }
              }.merge(options)
            end

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
    end
  end
end
