# frozen_string_literal: true

module Pages
  module Groups
    module SubGroups
      module Elements
        module RadioButton
          class Component < ApplicationComponent
            include Phlex::Rails::Helpers::ImageTag

            def initialize(label:, description:, image_path:, name:, data: {})
              @label = label
              @description = description
              @image_path = image_path
              @name = name
              @data = data
            end

            def template
              li(data: { controller: "database-choice", active_rails_byte: false }, class: "menu-card-row") do
                label(class: "flex items-center px-4 py-2 sm:px-6") do
                  div(class: "min-w-0 flex-1 flex items-center") do
                    div(class: "flex-shrink-0") do
                      image_tag(@image_path)
                    end

                    div(class: "min-w-0 flex-1 px-4 md:grid md:gap-4") do
                      div do
                        div(class: "menu-card-row-title text-sm leading-5 font-semibold text-ruby truncate") do
                          plain @label
                        end

                        div(class: "menu-card-row-description mt-2 flex items-center text-sm leading-5 text-gray-500 max-w-lg truncate pr-10") do
                          span { plain @description }
                        end
                      end

                      div(class: "hidden md:block")
                    end
                  end

                  div do
                    input(
                      type: "radio",
                      id: "main-tab-database-choice-#{@label.downcase}",
                      data: {
                        action: "change->database-choice#update",
                        **@data
                      },
                      name: @name,
                      value: @label,
                      checked: @data[:checked] || false,
                      autocomplete: "off",
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
