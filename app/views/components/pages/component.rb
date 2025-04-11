# frozen_string_literal: true

module Pages
  class Component < ApplicationComponent
    include Phlex::Rails::Helpers::LinkTo

    def initialize(page:, onboarding_step: nil)
      @page = page
      @onboarding_step = onboarding_step
    end

    def view_template
      if @page.groups.any? && has_visible_groups?
        div(class: "max-w-4xl mx-auto py-8 space-y-8") do
          div(class: "space-y-8") do
            @page.groups.order(:position).each do |group|
              render Pages::Groups::Component.new(group: group)
            end
          end
        end
      else
        div(class: "bg-white rounded-lg border border-gray-200") do
          render EmptyState::Component.new(
            user: Current.user,
            title: "No ingredients yet",
            description: "Get started by adding your first ingredient.",
            button_text: "Add new Ingredient",
            icon: true,
            button_path: new_ingredient_path,
            emoji: "🧂"
          )
        end
      end
    end

    private

    attr_reader :page

    def has_visible_groups?
      @page.groups.any? do |group|
        group.sub_groups.any? do |sub_group|
          sub_group.elements.any? do |element|
            Element.visible_for_user?(
              element,
              Current.user,
              @page.title
            )
          end
        end
      end
    end
  end
end
