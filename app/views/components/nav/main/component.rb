# frozen_string_literal: true

class Nav::Main::Component < ApplicationComponent
  include Phlex::Rails::Helpers::LinkTo
  include Phlex::Rails::Helpers::ButtonTo

  delegate :current_user, :current_page?, to: :helpers

  def view_template
    header(class: "bg-white border-b border-gray-200") do
      div(class: "max-w-7xl mx-auto px-4 sm:px-6 lg:px-8") do
        div(class: "flex justify-between items-center h-16") do
          # Logo on the left
          link_to(
            root_path,
            class: "flex items-center"
          ) do
            h1(class: "font-extrabold text-2xl tracking-tight text-gray-900") do
              plain "rails"
              span(class: "text-[#ac3b61]") { plain "new" }
              plain ".io"
            end
          end

          # Profile and Logout on the right
          if current_user
            div(class: "flex items-center space-x-4") do
              unless current_page?(dashboard_path)
                link_to(
                  dashboard_path,
                  class: "inline-flex items-center px-4 py-2 border border-gray-300 text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
                ) do
                  img(src: current_user.image, class: "w-5 h-5 rounded-full mr-2")
                  plain "Dashboard"
                end
              end

              button_to(
                "/sign_out",
                method: :delete,
                class: "inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md text-white bg-gray-900 hover:bg-gray-700"
              ) do
                github_icon
                plain "Logout"
              end
            end
          end
        end
      end
    end
  end

  private

  def github_icon
    svg(
      class: "w-5 h-5 mr-2",
      fill: "currentColor",
      viewbox: "0 0 24 24"
    ) do |s|
      s.path(
        fill_rule: "evenodd",
        clip_rule: "evenodd",
        d: "M12 2C6.477 2 2 6.484 2 12.017c0 4.425 2.865 8.18 6.839 9.504.5.092.682-.217.682-.483 0-.237-.008-.868-.013-1.703-2.782.605-3.369-1.343-3.369-1.343-.454-1.158-1.11-1.466-1.11-1.466-.908-.62.069-.608.069-.608 1.003.07 1.531 1.032 1.531 1.032.892 1.53 2.341 1.088 2.91.832.092-.647.35-1.088.636-1.338-2.22-.253-4.555-1.113-4.555-4.951 0-1.093.39-1.988 1.029-2.688-.103-.253-.446-1.272.098-2.65 0 0 .84-.27 2.75 1.026A9.564 9.564 0 0112 6.844c.85.004 1.705.115 2.504.337 1.909-1.296 2.747-1.027 2.747-1.027.546 1.379.202 2.398.1 2.651.64.7 1.028 1.595 1.028 2.688 0 3.848-2.339 4.695-4.566 4.943.359.309.678.92.678 1.855 0 1.338-.012 2.419-.012 2.747 0 .268.18.58.688.482A10.019 10.019 0 0022 12.017C22 6.484 17.522 2 12 2z"
      )
    end
  end
end
