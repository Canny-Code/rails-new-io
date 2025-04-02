# frozen_string_literal: true

module Pages
  module Groups
    class Component < ApplicationComponent
      def initialize(group:)
        @group = group
      end

      def view_template
        # Skip rendering if no subgroups would be visible
        return unless has_visible_subgroups?

        div(data_id: "rails-menu-card-holder") do
          div(class: "max-w-2xl mx-auto py-6 sm:px-6 lg:px-8") do
            div(data_id: "rails-menu-card", class: "max-w-none mx-auto") do
              div(class: "bg-white overflow-hidden sm:rounded-lg sm:shadow") do
                div(
                  data_id: "rails-menu-card-header",
                  class: "bg-deep-azure px-4 py-5 border-b border-gray-200 sm:px-6"
                ) do
                  div(
                    class:
                      "-ml-4 -mt-4 flex justify-between items-center flex-wrap sm:flex-no-wrap"
                  ) do
                    div(class: "ml-4 mt-4") do
                      h3(
                        class: "text-lg leading-6 font-medium text-azure-tint-100"
                      ) { @group.title }
                      p(class: "mt-1 text-sm leading-5 text-azure-tint-300") do
                        @group.description
                      end
                    end
                  end
                end
                ul(**wrapper_attributes, aria_disabled: "true") do
                  group.sub_groups.each do |sub_group|
                    render Pages::Groups::SubGroups::Component.new(sub_group: sub_group)
                  end
                end
              end
            end
          end
        end
      end

      private

      attr_reader :group

      def wrapper_attributes
        {
          class: "",
          **stimulus_attributes
        }
      end

      def stimulus_attributes
        group.stimulus_attributes.transform_keys { |key| "data-#{key}" }
      end

      def has_visible_subgroups?
        group.sub_groups.any? do |sub_group|
          sub_group.elements.any? do |element|
            Element.visible_for_user?(
              element,
              Current.user,
              group.page.title
            )
          end
        end
      end
    end
  end
end
