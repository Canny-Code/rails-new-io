class EmptyState::Component < ApplicationComponent
  include Phlex::Rails::Helpers::LinkTo

  def initialize(user:, title:, description:, button_text:, button_path:, emoji:)
    @user = user
    @title = title
    @description = description
    @button_text = button_text
    @button_path = button_path
    @emoji = emoji
  end

  def view_template
    div(class: "bg-white rounded-b-lg border-b border-l border-r border-gray-200 p-8") do
      div(class: "bg-gray-50 p-4 rounded-lg border border-gray-200") do
        div(class: "mt-8 text-center") do
          div(class: "text-6xl mb-4") { @emoji }
          h3(class: "mt-2 text-sm font-medium text-gray-900") { @title }
          p(class: "mt-1 text-sm text-gray-500") { @description }

          div(class: "mt-6 mb-8") do
            link_to(
              @button_path,
              class: "inline-flex items-center rounded-md bg-[#ac3b61] px-3 py-2 text-sm font-semibold text-white shadow-sm hover:bg-[#993351] focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-[#993351]"
            ) do
              svg(class: "-ml-0.5 mr-1.5 size-5", viewbox: "0 0 20 20", fill: "currentColor", aria_hidden: "true", data_slot: "icon") do |s|
                s.path(d: "M10.75 4.75a.75.75 0 0 0-1.5 0v4.5h-4.5a.75.75 0 0 0 0 1.5h4.5v4.5a.75.75 0 0 0 1.5 0v-4.5h4.5a.75.75 0 0 0 0-1.5h-4.5v-4.5Z")
              end
              plain @button_text
            end
          end
        end
      end
    end
  end
end
