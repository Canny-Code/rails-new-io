# frozen_string_literal: true

class Nav::Main::Component < ApplicationComponent
  include Phlex::Rails::Helpers::ButtonTo

  delegate :current_user, to: :helpers

  def view_template
    div(data_controller: "nav-mobile-menu") do
      div(class: "max-w-screen-xl mx-auto px-4 sm:px-6 sm:mt-0 md:mt-3 bg-white") do
        whitespace
        nav(class: "relative flex items-center justify-between sm:h-10 md:justify-center") do
          div(class: "flex items-center flex-1 md:absolute md:inset-y-0 md:left-0") do
            div(class: "flex items-center justify-end w-full md:w-auto") do
              div(class: "-mr-4 flex items-center md:hidden mt-3") do
                whitespace
                comment { "Mobile menu button" }
                whitespace
                button(
                  type: "button",
                  id: "hamburger-menu-open",
                  data_nav_mobile_menu_target: "hamburgerMenuOpen",
                  data_action: "click->nav-mobile-menu#toggleHamburger",
                  class: "inline-flex items-end justify-end p-2 rounded-md text-gray-400 hover:text-gray-500 hover:bg-gray-100 focus:outline-none focus:bg-gray-100 focus:text-gray-500 transition duration-150 ease-in-out"
                ) do
                  whitespace
                  svg(
                    class: "block h-6 w-6",
                    xmlns: "http://www.w3.org/2000/svg",
                    fill: "none",
                    viewbox: "0 0 24 24",
                    stroke: "currentColor",
                    aria_hidden: "true"
                  ) do |s|
                    s.path(
                      stroke_linecap: "round",
                      stroke_linejoin: "round",
                      stroke_width: "2",
                      d: "M4 6h16M4 12h16M4 18h16"
                    )
                  end
                  whitespace
                end
              end
            end
          end
          div(class: "hidden md:block") do
            whitespace
            nav_links.each do |link|
              a(
                href: link[:href],
                data_test_id: link[:test_id],
                class: "ml-10 first:ml-0 font-medium text-gray-500 px-1 pt-2 pb-3 border-b-2 border-transparent hover:text-gray-700 hover:border-gray-300 active:bg-green-600 transition duration-150 ease-in-out"
              ) { link[:text] }
              whitespace
            end
          end

          # Add Get in button on the right
          div(class: "hidden md:absolute md:flex md:items-center md:justify-end md:inset-y-0 md:right-0 gap-4") do
            if current_user
              render NotificationBadge::Component.new

              button_to(
                "/sign_out",
                method: :delete,
                class: "inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md text-white bg-gray-900 hover:bg-gray-700"
              ) do
                svg(
                  class: "w-5 h-5 mr-2",
                  fill: "currentColor",
                  viewbox: "0 0 24 24",
                  aria_hidden: "true"
                ) do |s|
                  s.path(
                    fill_rule: "evenodd",
                    clip_rule: "evenodd",
                    d: "M12 2C6.477 2 2 6.484 2 12.017c0 4.425 2.865 8.18 6.839 9.504.5.092.682-.217.682-.483 0-.237-.008-.868-.013-1.703-2.782.605-3.369-1.343-3.369-1.343-.454-1.158-1.11-1.466-1.11-1.466-.908-.62.069-.608.069-.608 1.003.07 1.531 1.032 1.531 1.032.892 1.53 2.341 1.088 2.91.832.092-.647.35-1.088.636-1.338-2.22-.253-4.555-1.113-4.555-4.951 0-1.093.39-1.988 1.029-2.688-.103-.253-.446-1.272.098-2.65 0 0 .84-.27 2.75 1.026A9.564 9.564 0 0112 6.844c.85.004 1.705.115 2.504.337 1.909-1.296 2.747-1.027 2.747-1.027.546 1.379.202 2.398.1 2.651.64.7 1.028 1.595 1.028 2.688 0 3.848-2.339 4.695-4.566 4.943.359.309.678.92.678 1.855 0 1.338-.012 2.419-.012 2.747 0 .268.18.58.688.482A10.019 10.019 0 0022 12.017C22 6.484 17.522 2 12 2z"
                  )
                end
                plain "Logout"
              end
            else
              button_to(
                "/auth/github",
                method: :post,
                data: { turbo: false },
                class: "inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md text-white bg-gray-900 hover:bg-gray-700"
              ) do
                svg(
                  class: "w-5 h-5 mr-2",
                  fill: "currentColor",
                  viewbox: "0 0 24 24",
                  aria_hidden: "true"
                ) do |s|
                  s.path(
                    fill_rule: "evenodd",
                    clip_rule: "evenodd",
                    d: "M12 2C6.477 2 2 6.484 2 12.017c0 4.425 2.865 8.18 6.839 9.504.5.092.682-.217.682-.483 0-.237-.008-.868-.013-1.703-2.782.605-3.369-1.343-3.369-1.343-.454-1.158-1.11-1.466-1.11-1.466-.908-.62.069-.608.069-.608 1.003.07 1.531 1.032 1.531 1.032.892 1.53 2.341 1.088 2.91.832.092-.647.35-1.088.636-1.338-2.22-.253-4.555-1.113-4.555-4.951 0-1.093.39-1.988 1.029-2.688-.103-.253-.446-1.272.098-2.65 0 0 .84-.27 2.75 1.026A9.564 9.564 0 0112 6.844c.85.004 1.705.115 2.504.337 1.909-1.296 2.747-1.027 2.747-1.027.546 1.379.202 2.398.1 2.651.64.7 1.028 1.595 1.028 2.688 0 3.848-2.339 4.695-4.566 4.943.359.309.678.92.678 1.855 0 1.338-.012 2.419-.012 2.747 0 .268.18.58.688.482A10.019 10.019 0 0022 12.017C22 6.484 17.522 2 12 2z"
                  )
                end
                plain "Get in"
              end
            end
          end
          whitespace
        end
      end
      div do
        div(
          id: "hamburger-menu-close",
          data_nav_mobile_menu_target: "hamburgerMenuClose",
          data_action: "click->nav-mobile-menu#toggleClose",
          class: "absolute top-0 inset-x-0 p-2 origin-top-right hidden z-50"
        ) do
          div(class: "rounded-lg shadow-md") do
            div(class: "rounded-lg bg-white shadow-xs overflow-hidden") do
              div(class: "px-5 pt-4") do
                div(class: "-mr-2") do
                  whitespace
                  button(
                    type: "button",
                    class: "absolute top-0 right-0 m-2 p-2 rounded-md text-gray-400 hover:text-gray-500 hover:bg-gray-100 focus:outline-none focus:bg-gray-100 focus:text-gray-500 transition duration-150 ease-in-out"
                  ) do
                    whitespace
                    comment { "X to close hamburger menu" }
                    whitespace
                    svg(
                      stroke: "currentColor",
                      fill: "none",
                      viewbox: "0 0 24 24",
                      class: "h-6 w-6"
                    ) do |s|
                      s.path(
                        stroke_linecap: "round",
                        stroke_linejoin: "round",
                        stroke_width: "2",
                        d: "M6 18L18 6M6 6l12 12"
                      ) { }
                    end
                    whitespace
                  end
                end
              end
              div(
                id: "mobile-navigation-dropdown",
                data_nav_mobile_menu_target: "mobileNavigationDropdown",
                class: "px-2 pt-2 pb-3"
              ) do
                whitespace
                nav_links.each do |link|
                  a(
                    href: link[:href],
                    class: "block px-3 py-2 text-base font-medium my-2 border-l-4 border-transparent text-deep-azure-zeta hover:text-gray-800 hover:bg-gray-100 hover:border-gray-400 transition duration-150 ease-in-out"
                  ) { link[:text] }
                  whitespace
                end
              end
            end
          end
        end
      end
    end
  end

  private

  def nav_links
    [
      { href: "/", text: " 🏠️ Home ", test_id: "main-nav-link-home" },
      { href: "/why", text: " 🤔 Why? ", test_id: "main-nav-link-why" },
      { href: "/live-demo", text: " 📽️ Live Demo ", test_id: "main-nav-link-live-demo" },
      { href: "/about", text: " 📨 About / Contact ", test_id: "main-nav-link-about" }
    ]
  end
end
