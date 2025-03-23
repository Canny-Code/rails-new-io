class OnboardingSidebarStep::Component < ApplicationComponent
  def initialize(title:, description:, completed: false, current: false)
    @title = title
    @description = description
    @completed = completed
    @current = current
  end

  def view_template
    li(class: "relative pb-10") do
      div(class: "absolute left-4 top-4 -ml-px mt-0.5 h-full w-0.5 #{@completed ? 'bg-[#008A05]' : 'bg-gray-300'}", aria: { hidden: true })

      div(class: "group relative flex items-start") do
        span(class: "flex h-9 items-center") do
          if @completed
            span(class: "relative z-10 flex size-8 items-center justify-center rounded-full bg-[#008A05]") do
              svg(class: "size-5 text-white", viewBox: "0 0 20 20", fill: "currentColor", aria: { hidden: true }, data: { slot: "icon" }) do |svg|
                svg.path(fill_rule: "evenodd", d: "M16.704 4.153a.75.75 0 0 1 .143 1.052l-8 10.5a.75.75 0 0 1-1.127.075l-4.5-4.5a.75.75 0 0 1 1.06-1.06l3.894 3.893 7.48-9.817a.75.75 0 0 1 1.05-.143Z", clip_rule: "evenodd")
              end
            end
          elsif @current
            span(class: "relative z-10 flex size-8 items-center justify-center rounded-full border-2 border-[#008A05] bg-white") do
              span(class: "size-2.5 rounded-full bg-[#008A05]")
            end
          else # upcoming step
            span(class: "relative z-10 flex size-8 items-center justify-center rounded-full border-2 border-gray-300 bg-white group-hover:border-gray-400") do
              span(class: "size-2.5 rounded-full bg-transparent group-hover:bg-gray-300")
            end
          end
        end

        span(class: "ml-4 flex min-w-0 flex-col") do
          span(class: "text-sm font-medium") { @title }
          span(class: "text-sm text-gray-500") { @description }
        end
      end
    end
  end
end
