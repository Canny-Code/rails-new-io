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
                  action: "change->radio-button-choice#update"
                }
              )
            when "Element::Checkbox"
              render Pages::Groups::SubGroups::Elements::Checkbox::Component.new(
                label: element.label,
                description: element.description,
                image_path: element.image_path,
                name: "#{element.sub_group.group.title}",
                checked: element.variant.checked,
                command_line_value: element.command_line_value,
                display_when: element.variant.display_when,
                data: {
                  action: "change->check-box#update",
                  **group_stimulus_attributes
                }
              )
            when "Element::TextField"
              render Pages::Groups::SubGroups::Elements::TextField::Component.new(
                label: element.label,
                description: element.description,
                name: element.label,
              )
            else
              raise "Unknown element variant_type: #{element.variant_type}"
            end
          end

          private

          attr_reader :element

          def group_stimulus_attributes
            element.sub_group.group.stimulus_attributes.transform_keys do |key|
              case key
              when "controller"
                "action"
              else
                key
              end
            end
          end
        end
      end
    end
  end
end
