class ResourceTable::Component < ApplicationComponent
  include Phlex::Rails::Helpers::LinkTo
  include Phlex::Rails::Helpers::ButtonTo

  def initialize(resources:, columns:, actions: [ :view, :edit, :delete ])
    @resources = resources
    @columns = columns
    @actions = actions
  end

  def template
    table(class: "min-w-full divide-y divide-gray-300") do
      thead do
        tr do
          @columns.each do |column|
            th(scope: "col", class: column_header_classes(column)) do
              render_header(column)
            end
          end
          th(scope: "col", class: "relative py-3.5 pl-3 pr-4 sm:pr-0") do
            span(class: "sr-only") { "Actions" }
          end
        end
      end

      tbody(class: "divide-y divide-gray-200 bg-white") do
        @resources.each do |resource|
          tr do
            @columns.each do |column|
              td(class: column_cell_classes(column)) do
                render_cell_content(resource, column)
              end
            end
            render_actions_cell(resource)
          end
        end
      end
    end
  end

  private

  def column_header_classes(column)
    if column == @columns.first
      "py-3.5 pl-4 pr-3 text-left text-sm font-semibold text-gray-900 sm:pl-0"
    else
      "px-3 py-3.5 text-left text-sm font-semibold text-gray-900"
    end
  end

  def column_cell_classes(column)
    if column == @columns.first
      "whitespace-nowrap py-5 pl-4 pr-3 text-sm sm:pl-0"
    else
      "whitespace-nowrap px-3 py-5 text-sm text-gray-500"
    end
  end

  def render_cell_content(resource, column)
    content = column[:content].call(resource)

    if column == @columns.first
      div(class: "flex items-center") do
        div(class: "ml-4") do
          div(class: "font-medium text-gray-900") do
            if column[:link]
              link_to(content, column[:link].call(resource))
            else
              plain content
            end
          end
          if column[:subcontent]
            div(class: "mt-1 text-gray-500") { column[:subcontent].call(resource) }
          end
        end
      end
    else
      plain content
    end
  end

  def render_actions_cell(resource)
    td(class: "whitespace-nowrap px-3 py-5 text-sm text-gray-500") do
      div(class: "flex justify-end gap-4") do
        render_view_button(resource) if @actions.include?(:view)
        render_edit_button(resource) if @actions.include?(:edit)
        render_delete_button(resource) if @actions.include?(:delete)
      end
    end
  end

  def render_view_button(resource)
    link_to(send("#{resource.class.name.downcase}_path", resource), class: "text-gray-400 hover:text-gray-500") do
      span(class: "sr-only") { "View #{resource.class.name.downcase}" }
      svg(class: "w-6 h-6", xmlns: "http://www.w3.org/2000/svg", fill: "none", viewbox: "0 0 24 24", stroke: "currentColor") do |s|
        s.path(stroke_linecap: "round", stroke_linejoin: "round", stroke_width: "2", d: "M15 12a3 3 0 11-6 0 3 3 0 016 0z")
        s.path(stroke_linecap: "round", stroke_linejoin: "round", stroke_width: "2", d: "M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z")
      end
    end
  end

  def render_edit_button(resource)
    link_to([ :edit, resource ], class: "text-gray-400 hover:text-gray-500") do
      span(class: "sr-only") { "Edit #{resource.class.name.downcase}" }
      svg(class: "w-6 h-6", xmlns: "http://www.w3.org/2000/svg", fill: "none", viewbox: "0 0 24 24") do |s|
        s.path(fill_rule: "evenodd", clip_rule: "evenodd", d: "M21.1213 2.70705C19.9497 1.53548 18.0503 1.53547 16.8787 2.70705L15.1989 4.38685L7.29289 12.2928C7.16473 12.421 7.07382 12.5816 7.02986 12.7574L6.02986 16.7574C5.94466 17.0982 6.04451 17.4587 6.29289 17.707C6.54127 17.9554 6.90176 18.0553 7.24254 17.9701L11.2425 16.9701C11.4184 16.9261 11.5789 16.8352 11.7071 16.707L19.5556 8.85857L21.2929 7.12126C22.4645 5.94969 22.4645 4.05019 21.2929 2.87862L21.1213 2.70705ZM18.2929 4.12126C18.6834 3.73074 19.3166 3.73074 19.7071 4.12126L19.8787 4.29283C20.2692 4.68336 20.2692 5.31653 19.8787 5.70705L18.8622 6.72357L17.3068 5.10738L18.2929 4.12126ZM15.8923 6.52185L17.4477 8.13804L10.4888 15.097L8.37437 15.6256L8.90296 13.5112L15.8923 6.52185ZM4 7.99994C4 7.44766 4.44772 6.99994 5 6.99994H10C10.5523 6.99994 11 6.55223 11 5.99994C11 5.44766 10.5523 4.99994 10 4.99994H5C3.34315 4.99994 2 6.34309 2 7.99994V18.9999C2 20.6568 3.34315 21.9999 5 21.9999H16C17.6569 21.9999 19 20.6568 19 18.9999V13.9999C19 13.4477 18.5523 12.9999 18 12.9999C17.4477 12.9999 17 13.4477 17 13.9999V18.9999C17 19.5522 16.5523 19.9999 16 19.9999H5C4.44772 19.9999 4 19.5522 4 18.9999V7.99994Z", fill: "currentColor")
      end
    end
  end

  def render_delete_button(resource)
    button_to(resource,
      method: :delete,
      class: "text-gray-400 hover:text-gray-500",
      form: { data: { turbo_confirm: "Are you sure?" } }) do
      span(class: "sr-only") { "Delete #{resource.class.name.downcase}" }
      svg(class: "w-6 h-6", xmlns: "http://www.w3.org/2000/svg", fill: "none", viewbox: "0 0 24 24") do |s|
        s.g(id: "SVG_delete") do |g|
          g.path(d: "M10 12V17", stroke: "currentColor", stroke_width: "2", stroke_linecap: "round", stroke_linejoin: "round")
          g.path(d: "M14 12V17", stroke: "currentColor", stroke_width: "2", stroke_linecap: "round", stroke_linejoin: "round")
          g.path(d: "M4 7H20", stroke: "currentColor", stroke_width: "2", stroke_linecap: "round", stroke_linejoin: "round")
          g.path(d: "M6 10V18C6 19.6569 7.34315 21 9 21H15C16.6569 21 18 19.6569 18 18V10", stroke: "currentColor", stroke_width: "2", stroke_linecap: "round", stroke_linejoin: "round")
          g.path(d: "M9 5C9 3.89543 9.89543 3 11 3H13C14.1046 3 15 3.89543 15 5V7H9V5Z", stroke: "currentColor", stroke_width: "2", stroke_linecap: "round", stroke_linejoin: "round")
        end
      end
    end
  end

  def render_header(column)
    if column[:sortable]
      sort_link_to(column[:header], column[:sort_key])
    else
      plain column[:header]
    end
  end
end
