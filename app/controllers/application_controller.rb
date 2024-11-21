class ApplicationController < ActionController::Base
  allow_browser versions: :modern

  protect_from_forgery with: :exception
  helper_method :current_user
  helper_method :user_signed_in?

  def authenticate_user!
    redirect_to root_path, alert: "Please sign in first." unless user_signed_in?
  end

  def current_user
    @current_user ||= User.find_by(id: session[:user_id]) if session[:user_id]
  end

  def user_signed_in?
    !!current_user
  end
end
