# frozen_string_literal: true

module Pages
  class Component < ApplicationComponent
    include Phlex::Rails::Helpers::LinkTo

    def initialize(page:, onboarding_step: nil)
      @page = page
      @onboarding_step = onboarding_step
    end

    def view_template
      if @page.groups.any?
        if @onboarding_step.present?
          div(class: "flex gap-0 max-w-6xl mx-auto") do
            #  Left sidebar (1/3)
            render "shared/onboarding_sidebar"

            # Main content (2/3)
            div(class: "space-y-8 w-2/3 ") do
              @page.groups.each do |group|
                render Pages::Groups::Component.new(group: group)
              end
            end
          end
        else
          div(class: "max-w-4xl mx-auto py-8 space-y-8") do
            div(class: "space-y-8") do
              @page.groups.each do |group|
                render Pages::Groups::Component.new(group: group)
              end
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
  end
end
