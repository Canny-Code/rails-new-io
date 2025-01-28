class ResourceLayout::Component < ApplicationComponent
  def initialize(title:, subtitle:, new_button_text: nil, new_button_path: nil, resources:, empty_state: nil, columns:, actions: [ :view, :edit, :delete ], search: false, secondary_actions: nil)
    @title = title
    @subtitle = subtitle
    @new_button_text = new_button_text
    @new_button_path = new_button_path
    @resources = resources
    @empty_state = empty_state
    @columns = columns
    @actions = actions
    @search = search
    @secondary_actions = secondary_actions
  end

  def view_template
    div(class: "max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8") do
      div(class: "mt-8 flex flex-col") do
        div(class: "-my-2 -mx-4 overflow-x-auto sm:-mx-6 lg:-mx-8") do
          div(class: "inline-block min-w-full py-2 align-middle md:px-6 lg:px-8") do
            div(class: "overflow-hidden shadow ring-1 ring-black ring-opacity-5 md:rounded-lg") do
              render_header
              if @resources.any?
                div(class: "px-4 sm:px-6 lg:px-8") do
                  render ResourceTable::Component.new(
                    resources: @resources,
                    columns: @columns,
                    actions: @actions
                  )
                end
              else
                render @empty_state if @empty_state
              end
            end
          end
        end
      end

      if @secondary_actions
        div(class: "flex justify-end gap-4 mt-8") do
          Array(@secondary_actions).each do |action|
            unsafe_raw action
          end
        end
      end
    end
  end

  private

  def render_header
    div(class: "sm:flex sm:items-center mb-8 px-8 pt-8") do
      div(class: "sm:flex-auto") do
        h1(class: "text-2xl font-semibold text-gray-900") { @title }
        p(class: "mt-2 text-sm text-gray-700") { @subtitle }
      end

      if @new_button_text && @new_button_path
        div(class: "mt-4 sm:mt-0 sm:ml-16 sm:flex-none") do
          render Buttons::Primary::Component.new(
            text: @new_button_text,
            path: @new_button_path
          )
        end
      end
    end
  end
end
