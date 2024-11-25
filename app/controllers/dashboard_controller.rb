class DashboardController < ApplicationController
  DEFAULT_SORT_COLUMN = "created_at"
  DEFAULT_SORT_DIRECTION = "desc"
  ALLOWED_SORT_COLUMNS = %w[name status created_at].freeze
  ALLOWED_SORT_DIRECTIONS = %w[asc desc].freeze

  before_action :authenticate_user!

  def show
    @pagy, @generated_apps = pagy(
      current_user.generated_apps
        .includes(:app_status)
        .order(sort_column => sort_direction)
    )

    if params[:status].present?
      @generated_apps = @generated_apps.joins(:app_status)
                                     .where(app_statuses: { status: params[:status] })
    end

    if params[:search].present?
      @generated_apps = @generated_apps.where("name LIKE ?", "%#{params[:search]}%")
    end

    if params[:sort].present?
      @generated_apps = @generated_apps.order(params[:sort] => params[:direction])
    end
  end

  private

  def sort_column
    ALLOWED_SORT_COLUMNS.include?(params[:sort]) ? params[:sort] : DEFAULT_SORT_COLUMN
  end

  def sort_direction
    ALLOWED_SORT_DIRECTIONS.include?(params[:direction]) ? params[:direction] : DEFAULT_SORT_DIRECTION
  end
end
