class NotificationsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_notification, only: [ :update ]

  def index
    @notifications = current_user.notifications.newest_first
  end

  def update
    @notification.mark_as_read!
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to notifications_path }
    end
  end

  private

  def set_notification
    @notification = Noticed::Notification.where(recipient: current_user).find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to notifications_path, alert: "Notification not found"
  end
end
