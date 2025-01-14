# frozen_string_literal: true

module Pages
  module Groups
    module SubGroups
      class Component < ApplicationComponent
        def initialize(sub_group:)
          @sub_group = sub_group
        end

        def view_template
          if @sub_group.title == "Default"
            @sub_group.elements.order(:position).each do |element|
              render Pages::Groups::SubGroups::Elements::Component.new(element: element)
            end
          else
            # TODO: Implement non-default sub_group rendering
            # This would likely include the sub_group title and potentially
            # different styling/layout for its groups
          end
        end
      end
    end
  end
end
