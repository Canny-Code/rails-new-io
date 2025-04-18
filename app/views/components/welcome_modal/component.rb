class WelcomeModal::Component < ApplicationComponent
  include Phlex::Rails::Helpers::FormWith
  include Phlex::Rails::Helpers::ButtonTo

  def initialize(title:, description:, button_text:, button_path:)
    @title = title
    @description = description
    @button_text = button_text
    @button_path = button_path
  end

  def view_template
    div(data: { controller: "modal" }) do
      # Modal backdrop
      div(
        class: "fixed inset-0 bg-gray-500 bg-opacity-75 overflow-y-auto h-full w-full z-[9999]",
        data: {
          modal_target: "modal",
          action: "click->modal#clickOutside"
        }
      ) do
        # Modal content
        div(class: "relative top-20 mx-auto p-5 border w-full max-w-2xl shadow-lg rounded-md bg-white") do
          div(class: "mt-3") do
            # Content
            div(class: "px-4 py-2") do
              h3(class: "text-lg font-medium text-gray-900 mb-4") { @title }
              p(class: "text-sm text-gray-500 mb-6") { @description }

              div(class: "flex justify-end space-x-3") do
                button_to(
                  "No, Thanks",
                  onboarding_path,
                  method: :patch,
                  class: "inline-flex items-center rounded-md font-semibold transition ease-in-out duration-150 px-3 py-2 text-sm text-[#993351] hover:text-[#B34766] hover:bg-gray-50 focus:underline focus:text-[#993351] active:text-[#731F39] disabled:text-[#D3A9B6] disabled:cursor-not-allowed border border-[#993351] hover:border-[#B34766] active:border-[#731F39] disabled:border-[#D3A9B6]"
                )

                render Buttons::Primary::Component.new(
                  text: @button_text,
                  path: @button_path,
                  icon: false,
                  html_options: { data: { turbo_frame: "_top" } }
                )
              end
            end
          end
        end
      end
    end
  end
end
