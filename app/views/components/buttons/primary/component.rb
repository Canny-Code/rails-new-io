# frozen_string_literal: true

module Buttons
  module Primary
    class Component < ApplicationComponent
      include Phlex::Rails::Helpers::LinkTo
      include Phlex::Rails::Helpers::ButtonTag

      def initialize(text:, path: nil, size: :medium, icon: false, disabled: false, data: {}, html_options: {}, type: :link)
        @text = text
        @path = path
        @size = size
        @icon = icon
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
            render_content
          end
        end
      end

      private

      def render_content
        if @icon
          svg(class: "-ml-0.5 mr-1.5 size-5", viewbox: "0 0 20 20", fill: "currentColor", aria_hidden: "true", data_slot: "icon") do |s|
            s.path(d: "M10.75 4.75a.75.75 0 0 0-1.5 0v4.5h-4.5a.75.75 0 0 0 0 1.5h4.5v4.5a.75.75 0 0 0 1.5 0v-4.5h4.5a.75.75 0 0 0 0-1.5h-4.5v-4.5Z")
          end
        end
        plain @text
      end

      private

      def button_classes
        base_classes = "inline-flex items-center rounded-md font-semibold text-white shadow-sm transition ease-in-out duration-150"
        size_classes = @size == :large ? "px-8 py-2 text-md" : "px-3 py-2 text-sm"
        state_classes = "bg-[#993351] hover:bg-[#B34766] focus:bg-[#802A44] focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-[#802A44] active:bg-[#731F39] disabled:bg-[#D3A9B6] disabled:cursor-not-allowed"
        [ base_classes, size_classes, state_classes, @html_options[:class] ].reject(&:blank?).join(" ")
      end
    end
  end
end
