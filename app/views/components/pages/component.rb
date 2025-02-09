# frozen_string_literal: true

module Pages
  class Component < ApplicationComponent
    include Phlex::Rails::Helpers::LinkTo

    def initialize(page:)
      @page = page
    end

    def view_template
      div(class: "max-w-4xl mx-auto py-8 space-y-8") do
        if @page.groups.any?
          div(class: "space-y-8") do
            @page.groups.each do |group|
              render Pages::Groups::Component.new(group: group)
            end
          end
        else
          div(class: "bg-white rounded-lg border border-gray-200") do
            render EmptyState::Component.new(
              user: Current.user,
              title: "No ingredients yet",
              description: "Get started by adding your first ingredient.",
              button_text: "Add new ingredient",
              icon: true,
              button_path: new_ingredient_path,
              emoji: "🧂"
            )
          end
        end
      end
    end

    private

    attr_reader :page
  end
end
