# frozen_string_literal: true

class Nav::Main::Component < ApplicationComponent
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
