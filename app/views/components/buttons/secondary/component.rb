# app/views/components/buttons/secondary/component.rb
# frozen_string_literal: true

module Buttons
  module Secondary
    class Component < ApplicationComponent
      include Phlex::Rails::Helpers::LinkTo

      def initialize(text:, path:, size: :medium, custom_icon: nil, disabled: false, data: {}, html_options: {})
        @text = text
        @path = path
        @size = size
        @custom_icon = custom_icon
        @disabled = disabled
        @data = data
        @html_options = html_options
      end

      def view_template
        link_to(
          @path,
          class: button_classes,
          data: @data,
          **@html_options
        ) do
          render_custom_icon if @custom_icon
          plain @text
        end
      end

      private

      def render_custom_icon
        if @custom_icon.is_a?(Proc)
          @custom_icon.call
        else
          # Example: render a GitHub icon if @custom_icon is :github
          case @custom_icon
          when :github
            svg(class: "-ml-0.5 mr-1.5 size-5", viewbox: "0 0 24 24", fill: "currentColor", aria_hidden: "true") do |s|
              s.path(d: "M12 0C5.37 0 0 5.37 0 12c0 5.3 3.438 9.8 8.205 11.385.6.11.82-.26.82-.577v-2.17c-3.338.726-4.033-1.61-4.033-1.61-.546-1.387-1.333-1.757-1.333-1.757-1.09-.745.083-.73.083-.73 1.205.084 1.84 1.236 1.84 1.236 1.07 1.835 2.807 1.305 3.492.997.108-.775.42-1.305.763-1.605-2.665-.3-5.467-1.335-5.467-5.93 0-1.31.467-2.38 1.235-3.22-.123-.303-.535-1.523.117-3.176 0 0 1.007-.322 3.3 1.23a11.52 11.52 0 013.003-.403c1.02.005 2.045.137 3.003.403 2.29-1.552 3.295-1.23 3.295-1.23.655 1.653.243 2.873.12 3.176.77.84 1.235 1.91 1.235 3.22 0 4.61-2.807 5.625-5.48 5.92.43.37.823 1.102.823 2.222v3.293c0 .32.217.694.825.576C20.565 21.797 24 17.3 24 12c0-6.63-5.37-12-12-12z")
            end
          end
        end
      end

      def button_classes
        base_classes = "inline-flex items-center rounded-md font-semibold text-white shadow-sm transition ease-in-out duration-150"
        size_classes = @size == :large ? "px-8 py-4 text-lg" : "px-3 py-2 text-sm"
        state_classes = "bg-[#222222] hover:bg-[#444444] focus:bg-[#000000] focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-[#000000] active:bg-[#111111] disabled:bg-[#DDDDDD] disabled:cursor-not-allowed"
        "#{base_classes} #{size_classes} #{state_classes}"
      end
    end
  end
end
