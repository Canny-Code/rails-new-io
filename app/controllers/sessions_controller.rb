class SessionsController < ApplicationController
  def create
    @user = User.from_omniauth(request.env["omniauth.auth"])

    if @user.persisted?
      session[:user_id] = @user.id
      redirect_to redirect_path, notice: "Logged in as #{@user.name}"
    else
      redirect_to root_url, alert: "Failure"
    end
  end

  def destroy
    session[:user_id] = nil
    redirect_to root_path, notice: "Signed out"
  end

  def failure
    redirect_to root_path, alert: "Authentication failed"
  end

  private

  def redirect_path
    origin_path = URI(request.env["omniauth.origin"]).path rescue "/"

    if origin_path.present? && origin_path != "/" && origin_path != root_path
      request.env["omniauth.origin"]
    else
      dashboard_path
    end
  end
end
