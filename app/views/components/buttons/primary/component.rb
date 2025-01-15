# frozen_string_literal: true

module Buttons
  module Primary
    class Component < ApplicationComponent
      include Phlex::Rails::Helpers::LinkTo

      def initialize(text:, path:, icon: true)
        @text = text
        @path = path
        @icon = icon
      end

      def view_template
        link_to(
          @path,
          class: "inline-flex items-center rounded-md bg-[#ac3b61] px-3 py-2 text-sm font-semibold text-white shadow-sm hover:bg-[#993351] focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-[#993351]"
        ) do
          if @icon
            svg(class: "-ml-0.5 mr-1.5 size-5", viewbox: "0 0 20 20", fill: "currentColor", aria_hidden: "true", data_slot: "icon") do |s|
              s.path(d: "M10.75 4.75a.75.75 0 0 0-1.5 0v4.5h-4.5a.75.75 0 0 0 0 1.5h4.5v4.5a.75.75 0 0 0 1.5 0v-4.5h4.5a.75.75 0 0 0 0-1.5h-4.5v-4.5Z")
            end
          end
          plain @text
        end
      end
    end
  end
end 