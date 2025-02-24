# frozen_string_literal: true

require "test_helper"
require "support/phlex_component_test_case"

module Pages
  module Groups
    module SubGroups
      module Elements
        class ComponentTest < PhlexComponentTestCase
          test "raises error for unknown element variant type" do
            sub_group = SubGroup.new
            element = Element.new(sub_group: sub_group)
            element.stubs(:variant_type).returns("Element::UnknownType")

            component = Component.new(element: element)

            error = assert_raises(RuntimeError) do
              component.view_template
            end

            assert_equal "Unknown element variant_type: Element::UnknownType", error.message
          end

          test "renders custom ingredient checkbox" do
            ingredient = ingredients(:rails_authentication)

            group = Group.new(behavior_type: "custom_ingredient_checkbox")
            group.stubs(:title).returns("Custom Ingredients")

            sub_group = SubGroup.new(group: group)

            checkbox = Element::CustomIngredientCheckbox.new
            checkbox.stubs(:checked).returns(false)
            checkbox.stubs(:ingredient).returns(ingredient)

            element = Element.new(sub_group: sub_group)
            element.stubs(:variant_type).returns("Element::CustomIngredientCheckbox")
            element.stubs(:variant).returns(checkbox)
            element.stubs(:label).returns("Test Element")
            element.stubs(:description).returns("Test Description")
            element.stubs(:image_path).returns(nil)

            result = Component.new(element: element).render_in(view_context)
            doc = Nokogiri::HTML.fragment(result)

            input = doc.css("input[type='checkbox']").first
            assert_equal "custom-ingredient-test-element", input["id"]
            assert_equal "Test Element", input["data-command-output"]
            assert_equal ingredient.id.to_s, input["data-ingredient-id"]
            assert_equal "change->custom-ingredient-checkbox#update change->recipe-ui-state-store#ingredientChanged", input["data-action"]
            assert_equal "Custom Ingredients", input["name"]
            assert_nil input["checked"]
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
  end
end
