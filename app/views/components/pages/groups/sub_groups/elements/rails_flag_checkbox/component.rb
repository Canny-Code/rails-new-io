# frozen_string_literal: true

module Pages
  module Groups
    module SubGroups
      module Elements
        module RailsFlagCheckbox
          class Component < ApplicationComponent
            include Phlex::Rails::Helpers::ImageTag

            def initialize(label:, description:, image_path:, name:, command_line_value:, checked:, display_when:, data: {})
              @label = label
              @description = description
              @image_path = image_path.presence || "Database-generic.svg"
              @name = name
              @command_line_value = command_line_value
              @checked = checked
              @display_when = display_when
              @data = data.merge({
                "display-when": display_when
              })
            end

            def view_template
              li(class: "menu-card-row text-ruby") do
                whitespace
                label(
                  class: "flex items-center px-4 py-4 sm:px-6"
                ) do
                  div(class: "min-w-0 flex-1 flex items-center") do
                    div(class: "min-w-0 flex-1 px-4 md:grid md:gap-4") do
                      div do
                        div(
                          class:
                            "menu-card-row-title text-sm leading-5 font-semibold truncate"
                        ) { plain @label }
                        div(
                          class:
                            "menu-card-row-description mt-2 flex items-center text-sm leading-5 text-gray-500 max-w-lg"
                        ) do
                          whitespace
                          span { plain @description }
                        end
                      end
                    end
                  end

                  div do
                    input(
                      type: "checkbox",
                      id: "main-tab-mains-#{@label.downcase.gsub(' ', '-')}",
                      data: @data,
                      name: @name,
                      value: @command_line_value,
                      checked: @checked,
                      autocomplete: "off",
                      class: "form-checkbox text-deep-azure-gamma h-4 w-4 text-indigo-600 transition duration-150 ease-in-out"
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
