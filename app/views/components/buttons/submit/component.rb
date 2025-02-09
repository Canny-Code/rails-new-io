# frozen_string_literal: true

module Buttons
  module Submit
    class Component < ApplicationComponent
      include Phlex::Rails::Helpers::ButtonTag

      def initialize(text:, size: :medium, disabled: false, data: {}, html_options: {})
        @text = text
        @size = size
        @disabled = disabled
        @data = data
        @html_options = html_options
      end

      def view_template
        button_tag(
          type: "submit",
          class: combined_classes,
          disabled: @disabled,
          data: @data,
          **@html_options.except(:class)
        ) do
          plain @text
        end
      end

      private

      def button_classes
        base_classes = "inline-flex items-center rounded-md font-semibold transition ease-in-out duration-150"
        size_classes = @size == :large ? "px-8 py-4 text-lg" : "px-3 py-2 text-sm"
        state_classes = "text-white bg-[#008A05] hover:bg-[#006D04] focus:ring-2 focus:ring-offset-2 focus:ring-[#008A05] active:bg-[#005503] disabled:bg-[#99C49B] disabled:cursor-not-allowed"
        [ base_classes, size_classes, state_classes ]
      end

      def combined_classes
        [ button_classes, @html_options[:class] ].compact.join(" ")
      end
    end
  end
end
