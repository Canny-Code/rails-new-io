# frozen_string_literal: true

module Pages
  module Groups
    module SubGroups
      module Elements
        module RadioButton
          class Component < ApplicationComponent
            include Phlex::Rails::Helpers::ImageTag

            def initialize(label:, description:, image_path:, name:, command_line_value:, data: {})
              @label = label
              @description = description
              @image_path = image_path.presence
              @name = name
              @command_line_value = command_line_value
              @data = data
            end

            def view_template
              li(class: "menu-card-row") do
                label(class: "flex items-center px-4 py-4 sm:px-6") do
                  div(class: "min-w-0 flex-1 flex items-center") do
                    if @image_path.present?
                      div(class: "flex-shrink-0") do
                        image_tag(@image_path)
                      end
                    end

                    div(class: "min-w-0 flex-1 px-4 flex items-center") do
                      div(class: "flex flex-col justify-center") do
                        div(class: "menu-card-row-title text-sm leading-5 font-semibold text-ruby truncate") do
                          plain @label
                        end

                        div(class: "menu-card-row-description mt-2 flex items-center text-sm leading-5 text-gray-500 max-w-lg truncate pr-10") do
                          span { plain @description }
                        end
                      end
                    end
                  end

                  div do
                    input(
                      type: "radio",
                      id: "main-tab-database-choice-#{@label.downcase}",
                      data: @data,
                      name: @name,
                      value: @command_line_value,
                      checked: @data[:checked] || false,
                      class: "form-radio text-deep-azure-gamma h-4 w-4 text-indigo-600 transition duration-150 ease-in-out"
                    )
                  end
                end
              end
            end
          end
        end
      end
    end
  end
end
