# frozen_string_literal: true

module Pages
  class Component < ApplicationComponent
    def initialize(page:)
      @page = page
    end

    def view_template
      div(class: "max-w-4xl mx-auto py-8 space-y-8") do
        h1(class: "text-2xl font-bold mb-6") { page.title }

        div(class: "space-y-8") do
          @page.groups.each do |group|
            render Pages::Groups::Component.new(group: group)
          end
        end
      end
    end

    private

    attr_reader :page
  end
end
