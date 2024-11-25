module DashboardHelper
  def sort_link_to(name, column)
    current_direction = params[:direction] || DashboardController::DEFAULT_SORT_DIRECTION
    current_column = params[:sort] || DashboardController::DEFAULT_SORT_COLUMN

    direction = if column.to_s == current_column && current_direction == "asc"
      "desc"
    else
      "asc"
    end

    link_to(dashboard_path(
      sort: column,
      direction: direction,
      status: params[:status],
      search: params[:search]
    ),
      class: "group inline-flex items-center px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider",
      data: { turbo_frame: "generated_apps_list" }
    ) do
      concat name
      if column.to_s == current_column
        concat content_tag(:span, direction == "asc" ? "↓" : "↑", class: "ml-2")
      end
    end
  end
end
