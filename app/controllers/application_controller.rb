class ApplicationController < ActionController::Base
  include Pagy::Backend

  allow_browser versions: :modern

  protect_from_forgery with: :exception
  helper_method :current_user
  helper_method :user_signed_in?

  before_action :set_current_user

  def authenticate_user!
    redirect_to root_path, alert: "Please sign in first." unless user_signed_in?
  end

  def current_user
    Current.user
  end

  def user_signed_in?
    Current.user.present?
  end

  private

  def set_current_user
    Current.user = User.find_by(id: session[:user_id]) if session[:user_id]
  end
end
