# frozen_string_literal: true

module Pages
  module Groups
    module SubGroups
      module Elements
        module TextField
          class Component < ApplicationComponent
            include Phlex::Rails::Helpers::ImageTag

            def initialize(label:, description:, name:, data: {})
              @label = label
              @description = description
              @name = name
              @data = data
            end

            def view_template
              plain "TODO: Implement Text Field"
            end
          end
        end
      end
    end
  end
end
