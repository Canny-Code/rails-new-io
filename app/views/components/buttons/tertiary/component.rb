# app/views/components/buttons/tertiary/component.rb
# frozen_string_literal: true

module Buttons
  module Tertiary
    class Component < ApplicationComponent
      include Phlex::Rails::Helpers::LinkTo
      include Phlex::Rails::Helpers::ButtonTag

      def initialize(text:, path:, size: :medium, disabled: false, type: :link, data: {}, html_options: {})
        @text = text
        @path = path
        @size = size
        @disabled = disabled
        @data = data
        @html_options = html_options
        @type = type
      end

      def view_template
        if @type == :button
          button_tag(
            type: "button",
            class: button_classes,
            disabled: @disabled,
            data: @data,
            **@html_options.except(:class)
          ) do
            render_content
          end
        else
          link_to(
            @path,
            class: button_classes,
            data: @data,
            **@html_options.except(:class)
          ) do
            plain @text
          end
        end
      end

      private

      def button_classes
        base_classes = "inline-flex items-center rounded-md font-semibold transition ease-in-out duration-150"
        size_classes = @size == :large ? "px-8 py-4 text-lg" : "px-3 py-2 text-sm"
        state_classes = "text-[#993351] hover:text-[#B34766] hover:bg-gray-50 focus:underline focus:text-[#993351] active:text-[#731F39] disabled:text-[#D3A9B6] disabled:cursor-not-allowed"
        border_classes = "border border-[#993351] hover:border-[#B34766] active:border-[#731F39] disabled:border-[#D3A9B6]"
        [ base_classes, size_classes, state_classes, border_classes, @html_options[:class] ].reject(&:blank?).join(" ")
      end
    end
  end
end
