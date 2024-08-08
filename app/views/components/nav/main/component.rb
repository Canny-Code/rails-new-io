# frozen_string_literal: true

class Nav::Main::Component < ApplicationComponent
  def view_template
    div(data_controller: "mobile-menu") do
      div(
        class: "max-w-screen-xl mx-auto px-4 sm:px-6 sm:mt-0 md:mt-3 bg-white"
      ) do
        whitespace
        nav(
          class:
            "relative flex items-center justify-between sm:h-10 md:justify-center"
        ) do
          div(
            class: "flex items-center flex-1 md:absolute md:inset-y-0 md:left-0"
          ) do
            div(class: "flex items-center justify-end w-full md:w-auto") do
              div(class: "-mr-4 flex items-center md:hidden mt-3") do
                whitespace
                comment { "Mobile menu button" }
                whitespace
                button(
                  type: "button",
                  class:
                    "inline-flex items-end justify-end p-2 rounded-md text-gray-400 hover:text-gray-500 hover:bg-gray-100 focus:outline-none focus:bg-gray-100 focus:text-gray-500 transition duration-150 ease-in-out"
                ) do
                  whitespace
                  svg(
                    data_target: "mobile-menu.hamburger",
                    data_action: " click->mobile-menu#toggleHamburger",
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
            a(
              href: "/",
              class:
                "ml-10 first:ml-0 font-medium text-gray-500 px-1 pt-2 pb-3 border-b-2 border-transparent hover:text-gray-700 hover:border-gray-300 active:bg-green-600 transition duration-150 ease-in-out"
            ) { " 🏠️ Home " }
            whitespace
            a(
              href: "/why",
              class:
                "ml-10 first:ml-0 font-medium text-gray-500 px-1 pt-2 pb-3 border-b-2 border-transparent hover:text-gray-700 hover:border-gray-300 active:bg-green-600 transition duration-150 ease-in-out"
            ) { " 🤔 Why? " }
            whitespace
            a(
              href: "/live-demo",
              class:
                "ml-10 first:ml-0 font-medium text-gray-500 px-1 pt-2 pb-3 border-b-2 border-transparent hover:text-gray-700 hover:border-gray-300 active:bg-green-600 transition duration-150 ease-in-out"
            ) { " 📽️ Live Demo " }
            whitespace
            a(
              href: "/about",
              class:
                "ml-10 first:ml-0 font-medium text-gray-500 px-1 pt-2 pb-3 border-b-2 border-transparent hover:text-gray-700 hover:border-gray-300 active:bg-green-600 transition duration-150 ease-in-out"
            ) { " 📨 About / Contact " }
          end
          whitespace
        end
      end
      div do
        div(
          data_target: "mobile-menu.close",
          data_action: " click->mobile-menu#toggleClose",
          class: "absolute top-0 inset-x-0 p-2 origin-top-right hidden z-50"
        ) do
          div(class: "rounded-lg shadow-md") do
            div(class: "rounded-lg bg-white shadow-xs overflow-hidden") do
              div(class: "px-5 pt-4") do
                div(class: "-mr-2") do
                  whitespace
                  button(
                    type: "button",
                    class:
                      "absolute top-0 right-0 m-2 p-2 rounded-md text-gray-400 hover:text-gray-500 hover:bg-gray-100 focus:outline-none focus:bg-gray-100 focus:text-gray-500 transition duration-150 ease-in-out"
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
                data_target: "mobile-menu.navigation",
                class: "px-2 pt-2 pb-3"
              ) do
                whitespace
                a(
                  href: "/",
                  class:
                    "block px-3 py-2 text-base font-medium my-2 border-l-4 border-transparent text-deep-azure-zeta hover:text-gray-800 hover:bg-gray-100 hover:border-gray-400 transition duration-150 ease-in-out"
                ) { " 🏠️ Home " }
                whitespace
                a(
                  href: "/why",
                  class:
                    "block px-3 py-2 text-base font-medium my-2 border-l-4 border-transparent text-deep-azure-zeta hover:text-gray-800 hover:bg-gray-100 hover:border-gray-400 transition duration-150 ease-in-out"
                ) { " 🤔 Why? " }
                whitespace
                a(
                  href: "/live-demo",
                  class:
                    "block px-3 py-2 text-base font-medium my-2 border-l-4 border-transparent text-deep-azure-zeta hover:text-gray-800 hover:bg-gray-100 hover:border-gray-400 transition duration-150 ease-in-out"
                ) { " 📽️ Live Demo " }
                whitespace
                a(
                  href: "/about",
                  class:
                    "block px-3 py-2 text-base font-medium my-2 border-l-4 border-transparent text-deep-azure-zeta hover:text-gray-800 hover:bg-gray-100 hover:border-gray-400 transition duration-150 ease-in-out"
                ) { " 📨 About / Contact " }
              end
            end
          end
        end
      end
    end
  end
end
