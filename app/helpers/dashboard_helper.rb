module DashboardHelper
  def sort_link_to(name, column)
    direction = if params[:sort] == column.to_s && params[:direction] == "asc"
      "desc"
    else
      "asc"
    end

    icon = if params[:sort] == column.to_s
      direction == "asc" ? "↓" : "↑"
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
      if icon
        concat content_tag(:span, icon, class: "ml-2")
      end
    end
  end
end
