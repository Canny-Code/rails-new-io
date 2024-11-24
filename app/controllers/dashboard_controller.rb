class DashboardController < ApplicationController
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
    %w[name status created_at].include?(params[:sort]) ? params[:sort] : "created_at"
  end

  def sort_direction
    %w[asc desc].include?(params[:direction]) ? params[:direction] : "desc"
  end
end
