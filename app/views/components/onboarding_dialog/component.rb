class OnboardingDialog::Component < ApplicationComponent
  def initialize(onboarding_step:)
    @onboarding_step = onboarding_step
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
            # Close button
            div(class: "absolute top-0 right-0 pt-4 pr-4") do
              button(
                type: "button",
                class: "bg-white rounded-md text-gray-400 hover:text-gray-500 focus:outline-none",
                data: { action: "click->modal#close" }
              ) do
                span(class: "sr-only") { "Close" }
                svg(class: "h-6 w-6", fill: "none", viewbox: "0 0 24 24", stroke: "currentColor") do |s|
                  s.path(stroke_linecap: "round", stroke_linejoin: "round", stroke_width: "2", d: "M6 18L18 6M6 6l12 12")
                end
              end
            end

            # Content
            div(class: "px-4 py-2") do
              render "shared/onboarding/#{@onboarding_step}/explanation"
            end
          end
        end
      end
    end
  end
end
