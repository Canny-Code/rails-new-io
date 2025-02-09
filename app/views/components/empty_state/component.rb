class EmptyState::Component < ApplicationComponent
  include Phlex::Rails::Helpers::LinkTo

  def initialize(user:, title:, description:, button_text:, button_path:, emoji:, html_options: {})
    @user = user
    @title = title
    @description = description
    @button_text = button_text
    @button_path = button_path
    @emoji = emoji
    @html_options = html_options
  end

  def view_template
    div(class: "bg-white rounded-b-lg border-b border-l border-r border-gray-200 p-8") do
      div(class: "bg-gray-50 p-4 rounded-lg border border-gray-200") do
        div(class: "mt-8 text-center") do
          div(class: "text-6xl mb-4") { @emoji }
          h3(class: "mt-2 text-sm font-medium text-gray-900") { @title }
          p(class: "mt-1 text-sm text-gray-500") { @description }

          div(class: "mt-6 mb-8") do
            render Buttons::Primary::Component.new(
              text: @button_text,
              path: @button_path,
              html_options: @html_options
            )
          end
        end
      end
    end
  end
end
