# app/views/components/buttons/secondary/component.rb
# frozen_string_literal: true

module Buttons
  module Secondary
    class Component < ApplicationComponent
      include Phlex::Rails::Helpers::LinkTo

      def initialize(text:, path:, size: :medium, disabled: false, data: {}, html_options: {})
        @text = text
        @path = path
        @size = size
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
          plain @text
        end
      end

      private

      def button_classes
        base_classes = "inline-flex items-center rounded-md font-semibold text-white shadow-sm transition ease-in-out duration-150"
        size_classes = @size == :large ? "px-8 py-4 text-lg" : "px-3 py-2 text-sm"
        state_classes = "bg-[#222222] hover:bg-[#444444] focus:bg-[#000000] focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-[#000000] active:bg-[#111111] disabled:bg-[#DDDDDD] disabled:cursor-not-allowed"
        "#{base_classes} #{size_classes} #{state_classes}"
      end
    end
  end
end
