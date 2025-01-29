class SortLink::Component < ApplicationComponent
  include Phlex::Rails::Helpers::LinkTo
  include Phlex::Rails::Helpers::Routes

  delegate :params, to: :helpers

  DEFAULT_SORT_DIRECTION = "asc"
  DEFAULT_SORT_COLUMN = "created_at"

  def initialize(name:, column:)
    @name = name
    @column = column
  end

  def view_template
    current_direction = params[:direction] || DEFAULT_SORT_DIRECTION
    current_column = params[:sort] || DEFAULT_SORT_COLUMN

    direction = if @column.to_s == current_column && current_direction == "asc"
      "desc"
    else
      "asc"
    end

    link_to(
      dashboard_path(
        sort: @column,
        direction: direction,
        status: params[:status],
        search: params[:search]
      ),
      class: "group inline-flex items-center py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider",
      data: { turbo_frame: "generated_apps_list" }
    ) do
      plain @name
      if @column.to_s == current_column
        span(class: "ml-2") { plain direction == "asc" ? "↓" : "↑" }
      end
    end
  end
end
