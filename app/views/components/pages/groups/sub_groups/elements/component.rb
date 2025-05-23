# frozen_string_literal: true

module Pages
  module Groups
    module SubGroups
      module Elements
        class Component < ApplicationComponent
          def initialize(element:)
            @element = element
          end

          def view_template
            return unless visible_for_current_user?

            case element.variant_type
            when "Element::RadioButton"
              render Pages::Groups::SubGroups::Elements::RadioButton::Component.new(
                label: element.label,
                description: element.description,
                image_path: element.image_path,
                name: "#{element.sub_group.group.title}",
                command_line_value: element.command_line_value,
                data: {
                  checked: element.position == 0,
                  is_default: element.position == 0 ? "true" : "false",
                  element_id: element.id,
                  action: "change->radio-button-choice#update change->recipe-ui-state-store#radioSelected"
                }
              )
            when "Element::RailsFlagCheckbox"
              render Pages::Groups::SubGroups::Elements::RailsFlagCheckbox::Component.new(
                label: element.label,
                description: element.description,
                image_path: element.image_path,
                name: "#{element.sub_group.group.title}",
                checked: element.variant.checked,
                command_line_value: element.command_line_value,
                display_when: element.variant.display_when,
                data: {
                  action: "change->rails-flag-checkbox#update change->recipe-ui-state-store#railsFlagChanged",
                  element_id: element.id,
                  controller: "rails-flag-checkbox",
                  "rails-flag-checkbox-generated-output-outlet": "#rails-flags"
                }
              )
            when "Element::CustomIngredientCheckbox"
              render Pages::Groups::SubGroups::Elements::CustomIngredientCheckbox::Component.new(
                label: element.label,
                description: element.description,
                image_path: element.image_path,
                name: "#{element.sub_group.group.title}",
                checked: element.variant.checked,
                command_line_value: element.label,
                ingredient_id: element.variant.ingredient.id,
                ingredient_group_sub_group: element.cleaned_group_sub_group,
                data: {
                  action: "change->custom-ingredient-checkbox#update change->recipe-ui-state-store#ingredientChanged",
                  element_id: element.id,
                  controller: "custom-ingredient-checkbox",
                  "custom-ingredient-checkbox-generated-output-outlet": "#custom_ingredients"
                }
              )
            else
              raise "Unknown element variant_type: #{element.variant_type}"
            end
          end

          private

          attr_reader :element

          def visible_for_current_user?
            Element.visible_for_user?(
              element,
              Current.user,
              element.sub_group.group.page.title
            )
          end
        end
      end
    end
  end
end
