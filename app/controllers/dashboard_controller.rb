class DashboardController < ApplicationController
  DEFAULT_SORT_COLUMN = "created_at"
  DEFAULT_SORT_DIRECTION = "desc"
  ALLOWED_SORT_COLUMNS = %w[name status created_at].freeze
  ALLOWED_SORT_DIRECTIONS = %w[asc desc].freeze

  before_action :authenticate_user!

  def show
    @pagy, @generated_apps = pagy(filtered_apps)
  end

  private

  def filtered_apps
    apps = base_query
    apps = filter_by_status(apps)
    apps = filter_by_search(apps)
    apply_sorting(apps)
  end

  def base_query
    current_user.generated_apps
                .includes(:app_status)
                .order(sort_column => sort_direction)
  end

  def filter_by_status(scope)
    return scope if params[:status].blank?
    scope.joins(:app_status).where(app_statuses: { status: params[:status] })
  end

  def filter_by_search(scope)
    return scope if params[:search].blank?
    scope.where("name LIKE ?", "%#{sanitize_sql_like(params[:search])}%")
  end

  def apply_sorting(scope)
    return scope if params[:sort].blank?
    scope.order(sort_column => sort_direction)
  end

  def sort_column
    ALLOWED_SORT_COLUMNS.include?(params[:sort]) ? params[:sort] : DEFAULT_SORT_COLUMN
  end

  def sort_direction
    ALLOWED_SORT_DIRECTIONS.include?(params[:direction]) ? params[:direction] : DEFAULT_SORT_DIRECTION
  end

  def sanitize_sql_like(string)
    string.gsub(/[\\%_]/) { |m| "\\#{m}" }
  end
end
