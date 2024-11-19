# frozen_string_literal: true

module Pages
  module Groups
    module SubGroups
      module Elements
        class Component < ApplicationComponent
          def initialize(element:)
            @element = element
          end

          def template
            case element.variant_type
            when "Element::RadioButton"
              render Pages::Groups::SubGroups::Elements::RadioButton::Component.new(
                label: element.label,
                description: element.description,
                image_path: element.image_path,
                name: "#{element.sub_group.group.title}",
                data: {
                  checked: element.position == 0,
                  is_default: element.position == 0 ? "true" : "false",
                  action: "change->radio-button-choice#update"
                }
              )
            when "Element::Checkbox"
              render Pages::Groups::SubGroups::Elements::Checkbox::Component.new(element: element)
            when "Element::TextField"
              render Pages::Groups::SubGroups::Elements::TextField::Component.new(element: element)
            else
              raise "Unknown element variant_type: #{element.variant_type}"
            end
          end

          private

          attr_reader :element
        end
      end
    end
  end
end
